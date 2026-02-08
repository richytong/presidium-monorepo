#!/usr/bin/env node

if (process.env.NODE_ENV == null) {
  throw new Error('NODE_ENV required')
}

const AwsCredentials = require('presidium/AwsCredentials')
const AWSConfig = require('../AWSConfig.json')
const ports = require('../ports.json')
const package = require('./package')

setImmediate(async () => {
  const awsCreds = await AwsCredentials(AWSConfig.profile)
  awsCreds.region = AWSConfig.region

  const secretsManager = new SecretsManager({ ...awsCreds })

  const docker = new Docker({ apiVersion: '1.44' })

  const ecr = new ECR({ ...awsCreds })

  const image = `${package.name}:${package.version}`
  const registry = `${AWSConfig.accountId}.dkr.ecr.${AWSConfig.region}.amazonaws.com`

  const authToken = await ecr.getAuthorizationToken()
  const decoded = Buffer.from(options.authToken, 'base64').toString('utf8')
  const [username, password] = decoded.split(':')

  const servicePort = ports[service.name]

  const serviceOptions = {
    image: `${registry}/${image}`,
    cmd: ['./run.sh'],
    healthCmd: ['curl', '127.0.0.1:8080/health'],
    env: {
      NODE_ENV: process.env.NODE_ENV,
      ...package.env[process.env.NODE_ENV],
    },
    ...servicePort == null ? {} : {
      publish: {
        [servicePort]: 8080,
      },
    },
    replicas: 1,
    restart: 'any',
    username,
    password,
  }

  console.log(`Deploying ${package.name}@${package.version}...`)
  try {
    await docker.createService(package.name, serviceOptions)
  } catch (_error) {
    await docker.updateService(package.name, serviceOptions)
  }
})
