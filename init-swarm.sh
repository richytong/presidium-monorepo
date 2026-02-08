#!/usr/bin/env node

if (!process.env.NODE_ENV) {
  throw new Error('NODE_ENV required')
}

const AwsCredentials = require('presidium/AwsCredentials')
const SecretsManager = require('presidium/SecretsManager')
const DynamoDBTable = require('presidium/DynamoDBTable')
const Docker = require('presidium/Docker')
const AWSConfig = require('./AWSConfig.json')
const {
  name: swarmName,
} = require('./swarmConfig.json')[process.env.NODE_ENV]
const getPublicIPv4Address = require('./getPublicIPv4Address')

setImmediate(async () => {
  const awsCreds = await AwsCredentials(AWSConfig.profile)
  awsCreds.region = AWSConfig.region

  const secretsManager = new SecretsManager({ ...awsCreds })

  const swarmAddressTable = new DynamoDBTable({
    name: 'swarm_address',
    key: [{ address: 'string' }],
    ...awsCreds,
  })
  await swarmAddressTable.ready

  const docker = new Docker({ apiVersion: '1.44' })

  const address = getPublicIPv4Address()
  if (address == null) {
    throw new Error('Public IPv4 address not found.')
  }

  console.log('Initializing swarm...')
  await docker.initSwarm(`${address}:2377`)

  console.log('Saving join tokens...')
  const swarmData = await docker.inspectSwarm()
  await secretsManager.putSecret(`${swarmName}/WORKER_JOIN_TOKEN`, swarmData.JoinTokens.Worker)
  await secretsManager.putSecret(`${swarmName}/MANAGER_JOIN_TOKEN`, swarmData.JoinTokens.Manager)

  console.log('Saving swarm address...')
  await swarmAddressTable.putItemJSON({
    address,
    swarmName,
    createTime: Date.now(),
  })
})
