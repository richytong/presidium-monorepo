const Readable = require('presidium/Readable')
const square = require('./square')

async function squareHandler(request, response) {
  const buffer = await Readable.Buffer(request)
  const data = await buffer.toString('utf8')

  const n = Number(data)

  if (isNaN(n)) {
    response.writeHead(400, {
      'Access-Control-Allow-Origin': '*',
      'Content-Type': 'text/html',
    })
    response.end('Bad Request')
  }

  const n2 = square(n)

  response.writeHead(200, {
    'Access-Control-Allow-Origin': '*',
    'Content-Type': 'text/plain',
  })
  response.end(`${n2}`)
}

module.exports = squareHandler
