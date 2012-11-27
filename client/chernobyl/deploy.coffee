#!/usr/bin/env coffee
fs      = require 'fs'
path    = require 'path'
winston = require 'winston'
tar     = require 'tar'
zlib    = require 'zlib'
fstream = require 'fstream'
request = require 'request'
require 'colors'

task = exports

# Where is the app we are uploading located?
APP_DIR = '../example_app/'

# CLI output on the default output.
winston.cli()

# The actual task.
task.deploy = (ukraine_ip, cb) ->
    # Does the app have a package.json?
    pkg = fs.readFileSync "#{APP_DIR}package.json"

    # Pack 'this' directory and stream it to the server.
    fstream.Reader({'path': APP_DIR, 'type': 'Directory'})
    .pipe(tar.Pack())
    .pipe(zlib.createGzip())
    .pipe(request.put({'url': "http://#{ukraine_ip}:9002/deploy/username/appname"}, (err, res, body) ->
            console.log 'good'.green.bold
        )
    )