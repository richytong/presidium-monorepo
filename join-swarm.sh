#!/usr/bin/env node

if (!process.env.NODE_ENV) {
  throw new Error('NODE_ENV required')
}

const AwsCredentials = require('presidium/AwsCredentials')
const SecretsManager = require('presidium/SecretsManager')
const DynamoDBTable = require('presidium/DynamoDBTable')
const DynamoDBGlobalSecondaryIndex = require('presidium/DynamoDBGlobalSecondaryIndex')
const Docker = require('presidium/Docker')
const AWSConfig = require('./AWSConfig.json')
const {
  name: swarmName,
} = require('./swarmConfig.json')[process.env.NODE_ENV]
const getPublicIPv4Address = require('./getPublicIPv4Address')

setImmediate(async () => {
  const awsCreds = await AwsCredentials(AWSConfig.profile)
  awsCreds.region = AWSConfig.region

  const swarmAddressTable = new DynamoDBTable({
    name: 'swarm_address',
    key: [{ address: 'string' }],
    ...awsCreds,
  })
  await swarmAddressTable.ready

  const swarmAddressSwarmNameCreateTimeGSI = new DynamoDBGlobalSecondaryIndex({
    table: 'swarm_address',
    key: [{ swarmName: 'string' }, { createTime: 'number' }],
    ...awsCreds,
  })
  await swarmAddressSwarmNameCreateTimeGSI.ready

  const secretsManager = new SecretsManager({ ...awsCreds })

  const docker = new Docker()

  console.log('Finding swarm addresses...')
  const RemoteAddrs = await swarmAddressSwarmNameCreateTimeGSI.queryJSON(
    'swarmName = :swarmName AND createTime > :createTime',
    { swarmName, createTime: 1 },
    { Limit: 10, ScanIndexForward: false }
  ).then(data => data.ItemsJSON)

  console.log('Retrieving join token...')
  const isManager = process.argv.includes('-m') || process.argv.includes('--manager')
  const JoinToken = isManager
    ? await secretsManager.getSecretString(`${swarmName}/MANAGER_JOIN_TOKEN`)
    : await secretsManager.getSecretString(`${swarmName}/WORKER_JOIN_TOKEN`)

  console.log('Joining swarm...')
  await docker.joinSwarm('[::1]:2377', {
    JoinToken,
    RemoteAddrs,
  })

  const address = getPublicIPv4Address()
  if (address == null) {
    throw new Error('Public IPv4 address not found.')
  }

  console.log('Saving swarm address...')
  await swarmAddressTable.putItemJSON({
    address,
    swarmName,
    createTime: Date.now(),
  })
})
