fs = require('fs')
path = require('path')
async = require('async')
rimraf = require('rimraf')
mkdirp = require('mkdirp')
chai = require('chai')
Bystander = require('bystander')
should = chai.should()
ByMocha = require('../lib/by-mocha')
coffee = require('coffee-script')
ByCoffeeScript = require('by-coffeescript')
describe('ByMocha', ->
  GOOD_CODE = 'foo = 1'
  BAD_CODE = 'foo ==== 1'
  TMP = "#{__dirname}/tmp"
  FOO = "#{TMP}/foo"
  FOO2 = "#{TMP}/foo2"
  NODIR = "#{TMP}/nodir"
  NOFILE = "#{TMP}/nofile.coffee"
  HOTCOFFEE = "#{TMP}/hot.coffee"
  HOTJS = "#{TMP}/hot.js"
  HOTBASE = "#{TMP}/hot"
  BLACKCOFFEE = "#{TMP}/black.coffee"
  ICEDCOFFEE = "#{FOO}/iced.coffee"
  ICEDJS = "#{FOO}/iced.js"
  TESTCOFFEE = "#{FOO}/test.coffee"
  BIN = "#{FOO}/iced.bin.coffee"
  BINJS = "#{FOO}/iced"
  TMP_BASE = path.basename(TMP)
  FOO_BASE = path.basename(FOO)
  FOO2_BASE = path.basename(FOO2)
  NODIR_BASE = path.basename(NODIR)
  NOFILE_BASE = path.basename(NOFILE)
  HOTCOFFEE_BASE = path.basename(HOTCOFFEE)
  BLACKCOFFEE_BASE = path.basename(BLACKCOFFEE)
  ICEDCOFFEE_BASE = path.basename(ICEDCOFFEE)
  LINT_CONFIG = {"no_tabs" : {"level" : "error"}}
  TEST_PATHS = ["#{TMP}/foo/*"]
  SAMPLE_TEST = [
    "# dummy comment",
    "assert = require('assert')",  
    "hot = require('../hot')",
    "describe('sample test', ->",
    "  it('should be ok', () ->",
    "    assert.ok(1,1)",
    "  )",
    ")"
  ].join('\n')
  MAPPER = {"**/foo/*" : [/\/foo\//,'/foo2/']}
  bystander = new Bystander()
  byMocha = new ByMocha()
  stats = {}
  beforeEach((done) ->
    mkdirp(FOO, (err) ->
      async.forEach(
        [HOTCOFFEE, ICEDCOFFEE],
        (v, callback) ->
          fs.writeFile(v, GOOD_CODE, (err) ->
            async.forEach(
              [FOO, HOTCOFFEE,ICEDCOFFEE,BLACKCOFFEE],
              (v, callback2) ->
                fs.stat(v, (err,stat) ->
                  stats[v] = stat
                  callback2()
                )
              ->
                callback()
            )
          )
        ->
          byMocha = new ByMocha({nolog:true, root: TMP, testPaths: TEST_PATHS})
          done()
      )
    )
  )

  afterEach((done) ->
    rimraf(TMP, (err) =>
      byMocha.removeAllListeners()
      done()
    )
  )

  describe('constructor', ->
    it('init test', ->
      ByMocha.should.be.a('function')
    )
    it('should instanciate', ->
      byMocha.should.be.a('object')
    )
    it('should set @dependencyMap', () ->
      byMocha.dependencyMap.should.be.empty
    )
    it('should set @testPaths', () ->
      byMocha.testPaths.should.eql(TEST_PATHS)
    )
    it('should set @mochaStack', () ->
      byMocha.mochaStack.should.be.empty
    )
    it('should set @mocharunning', () ->
      byMocha.mocharunning.should.be.false
    )

  )

  describe('_isTest', ->
    it('should test if a path matches @testPaths', () ->
      byMocha._isTest(ICEDCOFFEE).should.be.ok
      byMocha._isTest(HOTCOFFEE).should.not.be.ok
    )
  )

  describe('_getTestDependencies', ->
    it('should get dependencies on a test', (done)->
      fs.writeFile(TESTCOFFEE, SAMPLE_TEST, () ->
        byMocha._getTestDependencies(TESTCOFFEE, () ->
          byMocha.dependencyMap["#{TMP}/hot"].should.include(TESTCOFFEE)
          done()
        )
      )
    )
  )

  describe('_parseNode', ->
    it('should parse a coffee node down and set @dependencyMap', (done) ->
        nodes = coffee.nodes(byMocha._removeComments(SAMPLE_TEST))
        byMocha._parseNode(nodes,TESTCOFFEE)
        byMocha.dependencyMap["#{TMP}/hot"].should.include(TESTCOFFEE)
        done()
    )
  )

  describe('_removeComents', ->
    it('should remove comments from the source', () ->
      byMocha._removeComments(SAMPLE_TEST).split('\n').should.not.include('# dummy comment')
    )
  )

  describe('_getTestPath', ->
    it('should return test file paths to execute for the file', (done) ->
      fs.writeFile(TESTCOFFEE, SAMPLE_TEST, () ->
        byMocha._getTestDependencies(TESTCOFFEE, () ->
          byMocha.dependencyMap["#{TMP}/hot"].should.include(TESTCOFFEE)
          byMocha._getTestPath("#{TMP}/hot").should.eql([TESTCOFFEE])
          done()
        )
      )
    )
  )

  describe('_removeTest', ->
    it('should remove a test from @dependencyMap', (done) ->
      fs.writeFile(TESTCOFFEE, SAMPLE_TEST, () ->
        byMocha._getTestDependencies(TESTCOFFEE, () ->
          byMocha.dependencyMap["#{TMP}/hot"].should.include(TESTCOFFEE)
          should.exist(byMocha.dependencyMap[TESTCOFFEE])
          byMocha._removeTest(TESTCOFFEE)
          should.not.exist(byMocha.dependencyMap[TESTCOFFEE])
          byMocha.dependencyMap["#{TMP}/hot"].should.not.include(TESTCOFFEE)
          done()
        )
      )
    )
  )

  describe('_registerTest', ->
    it('should register the filePath to @mochaStack', () ->
      byMocha.mocharunning = true
      byMocha._registerTest(TESTCOFFEE)
      byMocha.mochaStack.should.include(TESTCOFFEE)
    )
  )
  describe('_checkTest', ->
    it('should check if there is tests for the file path and register to @mochaStack', (done) ->
      byMocha.mocharunning = true
      fs.writeFile(TESTCOFFEE, SAMPLE_TEST, () ->
        byMocha._getTestDependencies(TESTCOFFEE, () ->
          byMocha.dependencyMap["#{TMP}/hot"].should.include(TESTCOFFEE)
          should.exist(byMocha.dependencyMap[TESTCOFFEE])
          byMocha._checkTest(TESTCOFFEE)
          byMocha.mochaStack.should.include(TESTCOFFEE)
          byMocha._checkTest(HOTCOFFEE)
          byMocha.mochaStack.should.not.include(HOTCOFFEE)
          byMocha._checkTest(HOTJS)
          byMocha.mochaStack.should.include(HOTBASE)
          done()
        )
      )
    )
  )

  describe('_mocha', ->
    it('run tests with mocha', (done) ->
      byMocha.mocharunning = true
      fs.writeFile(TESTCOFFEE, SAMPLE_TEST, () ->
        byMocha._getTestDependencies(TESTCOFFEE, () ->
          byMocha._checkTest(TESTCOFFEE)
          byMocha.mochaStack.should.include(TESTCOFFEE)
          byMocha.on('mocha', (data) ->
            data.result.passes.length.should.equal(1)
            done()
          )
          byMocha._mocha()
        )
      )
    )
  )
 
  describe('_setListeners', ->
    beforeEach( (done) ->
      bystander = new Bystander(TMP,{nolog:true, plugins:['by-coffeescript','by-write2js']})
      fs.writeFile(TESTCOFFEE, SAMPLE_TEST, () ->
        fs.unlink(ICEDCOFFEE, ()->
          done()
        )
      )
    )
    it('should listen to "File found" and register to @dependencyMap', (done) ->
      byMocha._setListeners(bystander)
      byMocha.once('set dependency', (file, dependency)->
        file.should.equal(TESTCOFFEE)
        dependency[HOTBASE].should.include(TESTCOFFEE)
        done()
      )
      bystander.run()
    )
    it('should listen to "File created" execute mocha tests', (done) ->
      byMocha.on('mocha', (data)->
        data.file.should.equal(HOTBASE)
        done()
      )
      bystander.on('watchset', (dir) ->
        dir.should.equal(TMP)
        fs.utimes(HOTCOFFEE, Date.now(), Date.now())
      )
      byMocha._setListeners(bystander)
      bystander.run()
    )
    it('should listen to "File changed" and execute mocha tests', (done) ->
      fs.writeFile(HOTJS, '', (err) ->
        byMocha.on('mocha', (data)->
          data.file.should.equal(HOTBASE)
          done()
        )
        bystander.once('beforewatch', (dir) ->
          bystander.by.write2js.on('wrote2js', (data) ->
            if data.jsfile is HOTJS
              fs.utimes(HOTJS,Date.now(),Date.now())
          )
          bystander.watch()
        )
        byMocha._setListeners(bystander)
        bystander.run(true)
      )
    )

  )
)