#!/usr/bin/env node

const AwsCredentials = require('presidium/AwsCredentials')
const NpmToken = require('presidium/NpmToken')
const SecretsManager = require('presidium/SecretsManager')
const Docker = require('presidium/Docker')
const ECR = require('presidium/ECR')
const fs = require('fs')
const AWSConfig = require('../AWSConfig.json')
const ports = require('../ports.json')
const monorepoPackage = require('../package.json')
const package = require('./package.json')

setImmediate(async function () {
  const env = process.env.NODE_ENV

  if (env == null) {
    throw new Error('NODE_ENV required')
  }

  const awsCreds = await AwsCredentials(AWSConfig.profile)
  awsCreds.region = AWSConfig.region

  const npmToken = await NpmToken()

  const secretsManager = new SecretsManager({ ...awsCreds })

  const npmrc = fs.createWriteStream(`${__dirname}/.npmrc`)
  npmrc.write(`//registry.npmjs.org/:_authToken=${npmToken}`)
  npmrc.end()

  await new Promise(resolve => {
    npmrc.on('close', resolve)
  })

  const secretsFile = fs.createWriteStream(`${__dirname}/.secrets`)
  secretsFile.write(`AWS_ACCESS_KEY_ID=${awsCreds.accessKeyId}\n`)
  secretsFile.write(`AWS_SECRET_ACCESS_KEY=${awsCreds.secretAccessKey}\n`)
  secretsFile.write(`AWS_REGION=${awsCreds.region}\n`)

  if (package.secrets) {
    for (const secretName of package.secrets[env] ?? []) {
      const secret = await secretsManager.getSecret(secretName)
      secretsFile.write(`${secretName}=${secret.SecretString}\n`)
    }
  }
  secretsFile.end()

  await new Promise(resolve => {
    secretsFile.on('close', resolve)
  })

  const docker = new Docker({ apiVersion: '1.44' })

  const ecr = new ECR({ ...awsCreds })

  const serviceRepository = `${monorepoPackage.name}/${package.name}`
  const image = `${serviceRepository}:${package.version}`

  const DockerfilePath = process.argv.includes('--Dockerfile')
    ? process.argv[process.argv.indexOf('--Dockerfile') + 1]
    : 'Dockerfile'

  const buildStream = await docker.buildImage(__dirname, {
    ignore: ['.github', 'node_modules', 'build-push', 'deploy', 'test.js'],
    image,
    platform: 'x86_64',
    archiveDockerfile: DockerfilePath,
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

  await ecr.createRepository(serviceRepository).catch(() => {})

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

  await fs.promises.rm(`${__dirname}/.npmrc`)
  await fs.promises.rm(`${__dirname}/.secrets`)
})