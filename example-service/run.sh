#!/usr/bin/env node

if (process.env.NODE_ENV == null) {
  throw new Error('NODE_ENV required')
}

const http = require('http')
const squareHandler = require('./squareHandler')
const exampleHandler = require('./exampleHandler')
const package = require('./package.json')
const {
  PORT,
} = package.env[process.env.NODE_ENV]

async function run() {
  const server = http.createServer(async (request, response) => {
    if (request.url.startsWith('/health')) {
      response.writeHead(200, {
        'Content-Type': 'text/plain',
      })
      response.end('ok')
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
    else if (request.method == 'POST' && request.url == '/square') {
      await squareHandler(request, response);
    }
    else {
      await exampleHandler(request, response)
    }
  })

  server.listen(PORT, () => {
    console.log('HTTP server listening on port', PORT)
  })
}

run()
