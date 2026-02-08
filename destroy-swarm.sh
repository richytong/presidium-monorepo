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

  const docker = new Docker({ apiVersion: '1.44' })

  console.log('Leaving swarm...')
  await docker.leaveSwarm({ force: true }).catch(console.error)

  console.log('Removing join tokens...')
  await secretsManager.deleteSecret(`${swarmName}/WORKER_JOIN_TOKEN`)
  await secretsManager.deleteSecret(`${swarmName}/MANAGER_JOIN_TOKEN`)

  console.log('Removing swarm addresses...')
  const iter = swarmAddressSwarmNameCreateTimeGSI.queryItemsIteratorJSON(
    'swarmName = :swarmName AND createTime > :createTime',
    { swarmName, createTime: 0 },
    { ScanItemsForward: true },
  )
  for await (const item of iter) {
    await swarmAddressTable.deleteItemJSON({ address: item.address })
  }

})
