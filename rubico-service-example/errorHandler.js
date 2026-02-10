/**
 * @name errorHandler
 *
 * @synopsis
 * ```coffeescript [specscript]
 * errorHandler(
 *   error Error,
 *   request Request,
 *   response Response
 * ) -> ()
 * ```
 */
const errorHandler = (error, request, response) => {
  if (typeof error.code != 'number') {
    error.code = 500
  }
  response.writeHead(error.code, {
    'Access-Control-Allow-Origin': '*',
    'Content-Type': 'text/plain',
  })
  response.end(error.message)
}

module.exports = errorHandler
