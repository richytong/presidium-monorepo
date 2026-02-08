function exampleHandler(request, response) {
  response.writeHead(200, {
    'Access-Control-Allow-Origin': '*',
    'Content-Type': 'text/html',
  })
  response.end('Example')
}

module.exports = exampleHandler
