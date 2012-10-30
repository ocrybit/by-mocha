By-Mocha
=============

A Bystander plugin to auto-run Mocha tests after file change events.  
Note it only works with CoffeeScript for now, and has to be used in conjunction with [by-coffeescript](http://tomoio.github.com/by-coffeescript/) and [by-write2js](http://tomoio.github.com/by-write2js/) plugins.

Installation
------------

To install **by-mocha**,

    sudo npm install -g by-mocha

Options
-------

> `testPaths` : comma separated paths for test sources  

#### Examples

Auto-run tests in `test` directory with Mocha.

    // .bystander config file
	.....
	.....
      "plugins" : ["by-coffeescript", "by-write2js", "by-mocha"],
      "by" : {
        "mocha" : {
          "testPaths" : ["test/*.coffee"]
        }
      },
    .....
	.....

`testPaths` will be resolved against the project root path.

Broadcasted Events for further hacks
------------------------

> `mocha` : successfully ran tests with mocha.  
> `set dependency` : set test dependencies for a new file.  
> `remove dependency` : removed test dependencies for a deleted file.

See the [annotated source](docs/by-mocha.html) for details.

Running Tests
-------------

Run tests with [mocha](http://visionmedia.github.com/mocha/)

    make
	
License
-------
**By-Mocha** is released under the **MIT License**. - see the [LICENSE](https://raw.github.com/tomoio/by-mocha/master/LICENSE) file

