#!/usr/bin/env node

process.env.NODE_ENV = 'test'

const Test = require('thunk-test')
const assert = require('assert')
const HTTP = require('presidium/HTTP')
const AwsCredentials = require('presidium/AwsCredentials')
const SecretsManager = require('presidium/SecretsManager')
const fs = require('fs')
const { spawn } = require('child_process')
const package = require('./package.json')
const AWSConfig = require('../AWSConfig.json')

const packageEnv = package.env[process.env.NODE_ENV]
for (const name in packageEnv) {
  process.env[name] = packageEnv[name]
}

async function test() {
  const thunkTests = Test.all([
    require('./square.test.js'),
  ])
  await thunkTests()

  const awsCreds = await AwsCredentials(AWSConfig.profile)
  awsCreds.region = AWSConfig.region

  const secretsManager = new SecretsManager({ ...awsCreds })
  const secretsFile = fs.createWriteStream(`${__dirname}/.secrets`)
  const packageSecrets = package.secrets[process.env.NODE_ENV]
  for (const secretName of packageSecrets) {
    try {
      const secret = await secretsManager.getSecret(secretName)
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

  const { promise: exitPromise, resolve, reject } = Promise.withResolvers()
  cmd.on('exit', code => {
    if (code == null || code == 0) {
      console.log('Success')
      resolve()
    } else {
      reject(new Error('Failure'))
    }
  })

  const cmdChunks = []
  cmd.stdout.on('data', chunk => {
    cmdChunks.push(chunk)
  })

  while (true) {
    const cmdStdoutText = Buffer.concat(cmdChunks).toString('utf8')
    if (cmdStdoutText.trim() == 'HTTP server listening on port 7357') {
      break
    }
    await new Promise(resolve => setTimeout(resolve, 100))
  }

  const http = new HTTP(`http://localhost:${process.env.PORT}/`)

  {
    const response = await http.get('/health')
    assert.equal(response.status, 200)
    const message = await response.text()
    assert.equal(message, 'ok')
  }

  {
    const response = await http.options('/')
    assert.equal(response.status, 204)
    const message = await response.text()
    assert.equal(message, '')
  }

  {
    const response = await http.get('/')
    assert.equal(response.status, 200)
    const message = await response.text()
    assert.equal(message, 'Example')
  }

  {
    const response = await http.post('/square', {
      body: '25',
    })
    assert.equal(response.status, 200)
    const message = await response.text()
    assert.equal(message, '625')
  }

  cmd.kill()
  await exitPromise
}

test()
