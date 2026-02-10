#!/usr/bin/env node

if (process.env.NODE_ENV == null) {
  throw new Error('NODE_ENV required')
}

require('rubico/global')
const http = require('http')
const Secrets = require('presidium/Secrets')
const DynamoDBTable = require('presidium/DynamoDBTable')
const AuthHandler = require('./AuthHandler')
const errorHandler = require('./errorHandler')

const { NODE_ENV } = process.env

async function run() {
  const secrets = await Secrets(`${__dirname}/.secrets`)

  console.log(map(secrets, secretValue => '*'.repeat(secretValue.length)))

  const awsCreds = {
    accessKeyId: secrets.AWS_ACCESS_KEY_ID,
    secretAccessKey: secrets.AWS_SECRET_ACCESS_KEY,
    region: process.env.AWS_REGION,
  }

  const dependencies = {}

  const accountTable = new DynamoDBTable({
    name: `BoC_${NODE_ENV}_account`,
    key: [{ username: 'string' }],
    ...awsCreds,
  })
  await accountTable.ready
  dependencies.accountTable = accountTable

  const authHandler = tryCatch(
    AuthHandler({ dependencies }),
    errorHandler
  )

  const server = http.createServer(async (request, response) => {
    if (request.url.startsWith('/health')) {
      response.writeHead(200, {
        'Content-Type': 'text/plain',
      })
      response.end('OK')
    }
    else if (request.method == 'OPTIONS') {
      response.writeHead(204, {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': '*',
        'Access-Control-Allow-Headers': '*',
        'Access-Control-Max-Age': '86400',
      })
      response.end();
    }
    else {
      authHandler(request, response)
    }
  })

  server.listen(process.env.PORT, () => {
    console.log('Server listening on port', process.env.PORT)
  })
}

run()
