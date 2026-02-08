const Test = require('thunk-test')
const square = require('./square')

const test = new Test('square', square)

test.case(-3, 9)
test.case(-2, 4)
test.case(-1, 1)
test.case(0, 0)
test.case(1, 1)
test.case(2, 4)
test.case(3, 9)
test.case(3, 9)
test.case(5, 25)
test.case(10, 100)

if (process.argv[1] == __filename) {
  test()
}

module.exports = test
