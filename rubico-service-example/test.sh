#!/usr/bin/env node

process.env.NODE_ENV = 'test'

const AwsCredentials = require('presidium/AwsCredentials')
const SecretsManager = require('presidium/SecretsManager')
const assert = require('assert')
const fs = require('fs')
const { spawn } = require('child_process')
const AWSConfig = require('../AWSConfig.json')
const package = require('./package.json')

const packageEnv = package.env[process.env.NODE_ENV]
for (const name in packageEnv) {
  process.env[name] = packageEnv[name]
}

const { NODE_ENV, PORT } = process.env

async function test() {
  const awsCreds = await AwsCredentials(AWSConfig.profile)
  awsCreds.region = AWSConfig.region

  const secretsManager = new SecretsManager({ ...awsCreds })
  const secretsFile = fs.createWriteStream(`${__dirname}/.secrets`)
  secretsFile.write(`AWS_ACCESS_KEY_ID=${awsCreds.accessKeyId}\n`)
  secretsFile.write(`AWS_SECRET_ACCESS_KEY=${awsCreds.secretAccessKey}\n`)
  secretsFile.write(`AWS_REGION=${awsCreds.region}\n`)
  const packageSecrets = package.secrets[NODE_ENV]
  for (const secretName of packageSecrets) {
    try {
      const secret = await secretsManager.getSecret(`${NODE_ENV}/${secretName}`)
      secretsFile.write(`${secretName}=${secret.SecretString}\n`)
    } catch (error) {
      error.secretName = secretName
      console.error(error)
      continue
    }
  }
  secretsFile.end()
  await new Promise(resolve => secretsFile.on('close', resolve))

  const cmd = spawn(`${__dirname}/run.sh`)
  cmd.stdout.pipe(process.stdout)
  cmd.stderr.pipe(process.stderr)

  process.on('exit', () => {
    cmd.kill()
  })

  const exitPromiseWithResolvers = Promise.withResolvers()
  cmd.on('exit', code => {
    if (code == null || code == 0) {
      console.log('Success')
      exitPromiseWithResolvers.resolve()
    } else {
      exitPromiseWithResolvers.reject(new Error('Failure'))
    }
  })

  const serverListeningPromiseWithResolvers = Promise.withResolvers()
  cmd.stdout.on('data', chunk => {
    const line = chunk.toString('utf8').trim()
    if (line == `Server listening on port ${PORT}`) {
      serverListeningPromiseWithResolvers.resolve()
    }
  })
  await serverListeningPromiseWithResolvers.promise

  const HTTP = require('presidium/HTTP')

  const http = new HTTP(`http://localhost:${PORT}`)

  {
    const response = await http.PUT('/boc-account/auth', {
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        username: 'newuser',
        password: 'password',
      }),
    })

    assert.equal(response.status, 404)
  }

  cmd.kill()

  await exitPromiseWithResolvers.promise
}

test()
