#!/usr/bin/env node

const AwsCredentials = require('presidium/AwsCredentials')
const NpmToken = require('presidium/NpmToken')
const SecretsManager = require('presidium/SecretsManager')
const fs = require('fs')
const AWSConfig = require('../AWSConfig.json')
const ports = require('../ports.json')
const package = require('./package.json')
const secrets = require('./secrets.json')

setImmediate(async function () {
  const env = process.env.NODE_ENV

  if (env == null) {
    throw new Error('NODE_ENV required')
  }

  const awsCreds = await AwsCredentials(AWSConfig.profile)
  awsCreds.region = AWSConfig.region

  const npmToken = await NpmToken()

  const secretsManager = new SecretsManager({ ...awsCreds })

  const npmrc = fs.createWriteStream('.npmrc')
  npmrc.write(`//registry.npmjs.org/:_authToken=${npmToken}`)
  npmrc.end()

  const secretsFile = fs.createWriteStream('.secrets')
  secretsFile.write(`AWS_ACCESS_KEY_ID=${awsCreds.accessKeyId}\n`)
  secretsFile.write(`AWS_SECRET_ACCESS_KEY=${awsCreds.secretAccessKey}\n`)
  secretsFile.write(`AWS_REGION=${awsCreds.region}\n`)

  for (const secretName of secrets[env] ?? []) {
    const secret = await secretsManager.getSecret(secretName)
    secretsFile.write(`${secretName}=${secret.SecretString}\n`)
  }
  secretsFile.end()

  const docker = new Docker({ apiVersion: '1.44' })

  const ecr = new ECR({ ...awsCreds })

  const image = `${package.name}:${package.version}`

  const buildStream = await docker.buildImage(path, {
    ignore: ['.github', 'node_modules', 'build-push', 'deploy', 'test.js'],
    image,
    archive: {
      Dockerfile: `
FROM node:24-alpine
WORKDIR /home/node
COPY . .
RUN apk add curl \
  && npm i \
  && rm .npmrc \
  && rm Dockerfile
USER node
      `, 
    },
    platform: 'x86_64',
  })

  buildStream.on('data', chunk => {
    const message = chunk.toString('utf8')
    if (message.includes('error')) {
      throw new Error(message)
    }
  })

  buildStream.pipe(process.stdout)

  await new Promise(resolve => buildStream.on('end', resolve))

  const registry = `${AWSConfig.accountId}.dkr.ecr.${AWSConfig.region}.amazonaws.com`

  await docker.tagImage(
    image,
    `${registry}/${image}`,
  )

  const authToken = await ecr.getAuthorizationToken()

  const pushStream = await docker.pushImage({
    image,
    registry,
    authToken,
  })
  pushStream.pipe(process.stdout)

  pushStream.on('data', chunk => {
    const message = chunk.toString('utf8')
    if (message.includes('error')) {
      throw new Error(message)
    }
  })

  await new Promise(resolve => pushStream.on('end', resolve))

  await fs.promises.rm('.npmrc')
  await fs.promises.rm('.secrets')
})

