# * Listen to messages from a parent and generate docco documents
# * This script should be forked by the main process

# ### Require Dependencies
 
# #### Third Party Modules
# `mocha` by [jashkenas@Jeremy Ashkenas](https://github.com/jashkenas/docco)
mocha = require('mocha')
require('coffee-script')
_ = require('underscore')
process.on('message',(data)=>
  file = data.file
  tests = []
  failures = []
  passes = []
  suites = []
  snumber = -1
  obj = {}
  clean = (test)=>
    return {
      title: test.title
      fullTitle: test.fullTitle()
      duration: test.duration,
      err: test.err
    }
  tester = new mocha()
  for v in data.mocha.files
    tester.addFile(v)
  tester.loadFiles()
  indents = 0
  runner = tester.run((err)=>
    obj = {
      tests: _(tests).map(clean)
      failures: _(failures).map(clean)
      passes: _(passes).map(clean)
    }
    process.send({result: obj, file: file, err: false, suites: suites})
  )
  runner.on('suite', (suite)=>
    snumber += 1
    indents += 1
    suite.indents = indents
    suites.push({indents:indents,title:suite.title,index:snumber})
  )
  runner.on('suite end', (suite)=>
    indents -= 1
  )
  runner.on('test end', (test)=>
    test.snumber = snumber
    tests.push(test)
  )

  runner.on('pass', (test)=>
    test.snumber = snumber
    passes.push(test)
  )

  runner.on('fail', (test)=>
    test.snumber = snumber
    failures.push(test)

  )

  runnner.on('end', (err,stats)=>

  )
)
