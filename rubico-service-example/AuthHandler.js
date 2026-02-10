require('rubico/global')
const Readable = require('presidium/Readable')
const StrictValidator = require('presidium/StrictValidator')
const Password = require('presidium/Password')

/**
 * @name AuthHandler
 *
 * @docs
 * ```coffeescript [specscript]
 * module presidium 'https://presidium.services/'
 * module http 'https://nodejs.org/docs/latest-v24.x/api/http.html'
 *
 * type Handler (request http.ClientRequest, response http.ServerResponse)=>Promise<>
 *
 * AuthHandler(options {
 *   dependencies: {
 *     accountTable: presidium.DynamoDBTable,
 *   },
 * }) -> handler Handler
 * ```
 */
function AuthHandler(options) {
  const {
    dependencies,
  } = options
  const {
    accountTable,
  } = dependencies

  return async function handler(request, response) {
    return pipe(Readable.Text(request), [
      JSON.parse,

      StrictValidator({
        username: String,
        password: String,
      }),

      async function getAccount(payload) {
        const { username } = payload
        try {
          const account = await accountTable.getItemJSON({
            username,
          }).then(get('ItemJSON'))
          return account
        } catch (error) {
          if (error.message.includes('Item not found')) {
            const error = new Error('Not Found')
            error.code = 404
            throw error
          }
          throw error
        }
        return { ...payload, account }
      },

      async function verifyPassword({ account, password }) {
        try {
          await Password.verify(password, account.passwordHash)
        } catch {
          const error = new Error('Unauthorized')
          error.code = 401
          throw error
        }
      },

      () => {
        response.writeHead(200, {
          'Access-Control-Allow-Origin': '*',
          'Content-Type': 'text/plain',
        })
        response.end('OK')
      },
    ])
  }
}

module.exports = AuthHandler
