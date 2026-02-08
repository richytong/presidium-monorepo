#!/usr/bin/env node

if (!process.env.NODE_ENV) {
  throw new Error('NODE_ENV required')
}

const { spawn } = require('child_process')
const walk = require('./walk')

setImmediate(async () => {
  const serviceNames = []
  for await (const filepath of walk(__dirname)) {
    if (filepath.endsWith('run.sh')) {
      const filepathParts = filepath.split('/')
      const serviceName = filepathParts[filepathParts.length - 2]
      serviceNames.push(serviceName)
    }
  }

  for (const serviceName of serviceNames) {
    const cmd = spawn(`${__dirname}/deploy.sh`, {
      env: {
        ...process.env,
        NODE_ENV: process.env.NODE_ENV,
      },
    })
    cmd.stdout.pipe(process.stdout)
    cmd.stderr.pipe(process.stderr)

    await new Promise((resolve, reject) => {
      cmd.on('error', error => {
        reject(error)
      })
      cmd.on('exit', () => {
        resolve()
      })
    })
  }
})
