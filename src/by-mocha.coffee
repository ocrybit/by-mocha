fs = require('fs')
path = require('path')
minimatch = require('minimatch')
util = require('util')
cp = require('child_process')
_ = require('underscore')
coffee = require('coffee-script')
EventEmitter = require('events').EventEmitter

module.exports = class ByMocha extends EventEmitter

  constructor: (@opts = {}) ->
    @dependencyMap = {}
    @testPaths = []
    if @opts.testPaths?
      @testPaths = (path.resolve(v) for v in @opts.testPaths)
    @mochaStack = []
    @mocharunning = false

  _setListeners: (@bystander) ->
    @bystander.on('File changed', (data) =>
      if data.file?
        filename = data.file
      else if typeof(data) is 'string'
        filename = data
      if @_isTest(filename)
        @_getTestDependencies(filename)
        @_registerTest(filename)
      else if path.extname(filename) is '.js'
        @_checkTest(filename,data)
    )
    @bystander.on('File created', (data) =>
      if data.file?
        filename = data.file
      else if typeof(data) is 'string'
        filename = data
      @_checkTest(filename,data)
      if @_isTest(filename)
        @_getTestDependencies(filename)
        @_registerTest(filename)
      else if path.extname(filename) is '.js'
        @_checkTest(filename,data)
    )
    @bystander.on('File found', (file, stat) =>
      if @_isTest(file)
        @_getTestDependencies(file)
    )

  _getTestDependencies: (file,cb) ->
    fs.readFile(file,'utf8', (err, body) =>
      unless err
        try
          set = false
          nodes = coffee.nodes(@_removeComments(body))
          @_parseNode(nodes,file)
          if not @dependencyMap[file]?
            @dependencyMap[file] = []
            set = true
          @dependencyMap[file].push(file)
          @dependencyMap[file] = _(@dependencyMap[file]).uniq()
          if set
            @emit('set dependency', file, @dependencyMap)
        catch e
          console.log(e)
      cb?()
    )

  _isTest: (file) ->
    if path.extname(file) is '.coffee' and @testPaths?
      for v in @testPaths
        if minimatch(file, v, {dot : true})
          return true
    return false

  _parseNode: (node,file) ->
    if node.value?.variable?.base?.value is 'require' and node.value.args?
      moduleName = node.value.args[0]?.base?.value.replace(/^\'/,'').replace(/\'$/,'').replace(/^\"/,'').replace(/\"$/,'')
      if moduleName.match(/\.{1,2}/) isnt null
        mpath = path.join(path.dirname(file),moduleName)
        if not @dependencyMap[mpath]?
          @dependencyMap[mpath] = []
        @dependencyMap[mpath].push(file)
        @dependencyMap[mpath] = _(@dependencyMap[mpath]).uniq()
    if util.isArray(node)
      for v, i in node
        @_parseNode(v,file)
    else if typeof(node) is 'object'
      for k, v of node
        if v?
          @_parseNode(v,file)
  
  _removeComments: (body) ->
    return (v for v in body.split('\n') when v.match(/^\s*\#/) is null).join('\n')

  _registerTest: (file) ->
    @mochaStack = (v for v in @mochaStack when v isnt file)
    @mochaStack.push(file)
    if @mocharunning is false
      @_mocha()

  _getTestPath: (src) ->
    if @dependencyMap[src]?
      return @dependencyMap[src]
    return false
  
  _removeTest: (filename) ->
    removed = false
    if @dependencyMap[filename]
      delete @dependencyMap[filename]
      removed = true
    for k, v of @dependencyMap
      @dependencyMap[k] = (v2 for v2, i2 in v when v2 isnt filename)
    if removed
      @emit('removed dependency', filename, @dependencyMap)
  _checkTest: (filename,data) ->
    if @dependencyMap[filename]?
      @_registerTest(filename)
    else if @dependencyMap[filename.replace(/\.js$/,'')]?
      @_registerTest(filename.replace(/\.js$/,''))

  _mocha: () ->
    @mocharunning = true
    src = @mochaStack.shift()
    testfile = @_getTestPath(src)
    unless testfile is false or testfile.length is 0
      files = testfile
      cp_mocha = cp.fork(__dirname + '/mocha', {silent:true})
      cp_mocha.on('message', (data) =>
        if data.err
          unless @opts.nolog
            console.log('Mocha: something went wrong!\n'.red)
        else
          unless @opts.nolog
            message = ["Mocha:"]
            if data.result.passes.length isnt 0
              message.push(" #{data.result.passes.length} tests passed!".green)
            if data.result.failures.length isnt 0
              message.push(" #{data.result.failures.length} tests failed!".red)
            message.push(" <= tests for #{src}".grey + '\n')
            console.log(message.join(''))
            console.log('')
            for v, i in data.result.failures
              console.log("#{i+1}) #{v.fullTitle}")
              console.log(v.err.message.red)
              console.log('')
        @emit('mocha', data)
        @mocharunning = false
        if @mochaStack.length isnt 0
          @_mocha()
      )
      cp_mocha.on('error', (err) =>
        console.log('Mocha: something went wrong!\n'.red)
      )
      cp_mocha.send({file:src, mocha : { files : files}})
    else
      @mocharunning = false
      if @mochaStack.length isnt 0
        @_mocha()

