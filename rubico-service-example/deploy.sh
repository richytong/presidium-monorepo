#!/usr/bin/env node

if (process.env.NODE_ENV == null) {
  throw new Error('NODE_ENV required')
}

const AwsCredentials = require('presidium/AwsCredentials')
const SecretsManager = require('presidium/SecretsManager')
const Docker = require('presidium/Docker')
const ECR = require('presidium/ECR')
const AWSConfig = require('../AWSConfig.json')
const ports = require('../ports.json')
const monorepoPackage = require('../package.json')
const package = require('./package')

setImmediate(async () => {
  const awsCreds = await AwsCredentials(AWSConfig.profile)
  awsCreds.region = AWSConfig.region

  const secretsManager = new SecretsManager({ ...awsCreds })

  const docker = new Docker({ apiVersion: '1.44' })

  const ecr = new ECR({ ...awsCreds })

  const registry = `${AWSConfig.accountId}.dkr.ecr.${AWSConfig.region}.amazonaws.com`
  const serviceRepository = `${monorepoPackage.name}/${package.name}`
  const image = `${serviceRepository}:${package.version}`

  const authToken = await ecr.getAuthorizationToken()
  const decoded = Buffer.from(authToken, 'base64').toString('utf8')
  const [username, password] = decoded.split(':')

  const serviceName = package.name.toLowerCase().replace(/[^a-z0-9]/g, '-')
  const servicePort = ports[package.name]

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

  console.log(`Deploying ${serviceName}@${package.version}...`)
  try {
    await docker.createService(serviceName, serviceOptions)
  } catch (_error) {
    await docker.updateService(serviceName, serviceOptions)
  }
})