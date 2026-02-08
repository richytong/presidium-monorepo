#!/usr/bin/env node

const fs = require('fs')

setImmediate(async () => {
  const serviceName = process.argv[2]

  if (!serviceName) {
    throw new Error('serviceName required.')
  }

  await fs.mkdir(`${__dirname}/${serviceName}`)
})
