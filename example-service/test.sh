#!/usr/bin/env node

process.env.NODE_ENV = 'test'

const Test = require('thunk-test')
const assert = require('assert')
const HTTP = require('presidium/HTTP')
const { spawn } = require('child_process')
const package = require('./package.json')

const packageEnv = package.env[process.env.NODE_ENV]
for (const name in packageEnv) {
  process.env[name] = packageEnv[name]
}

const aggregateUnitTest = Test.all([
  require('./square.test.js')
])

const integrationTest = new Test('test.sh', async function integration() {
  const cmd = spawn(`${__dirname}/run.sh`)
  cmd.stdout.pipe(process.stdout)
  cmd.stderr.pipe(process.stderr)

  process.on('exit', () => {
    cmd.kill()
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
}).case()

const test = Test.all([
  aggregateUnitTest,
  integrationTest,
])

test()
