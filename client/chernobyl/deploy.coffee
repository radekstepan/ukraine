#!/usr/bin/env coffee
fs      = require 'fs'
path    = require 'path'
winston = require 'winston'
tar     = require 'tar'
zlib    = require 'zlib'
fstream = require 'fstream'
request = require 'request'
Q       = require 'q'
require 'colors'

task = exports

# Where is the app we are uploading located?
APP_DIR = '../example_app'

# CLI output on the default output.
winston.cli()

# The actual task.
task.deploy = (ukraine_ip) ->
    # return fstream.Reader({ 'path': APP_DIR, 'type': 'Directory' })
    # .pipe(tar.Pack({ 'prefix': '.' }))
    # .pipe(zlib.Gzip())
    # .pipe(fstream.Writer({ 'path': 'app.tgz', 'type': 'File' }))

    # Read the app's `package.json` file.
    return Q.fcall( ->
        def = Q.defer()
        fs.readFile "#{APP_DIR}/package.json", 'utf-8', (err, text) ->
            if err then def.reject err
            else def.resolve text
        def.promise
    # JSON parse.
    ).then(
        (pkg) -> JSON.parse pkg
    # Author field.
    ).then(
        (pkg) ->
            # Defined?
            unless pkg.author and pkg.author.length > 0
                throw 'author'.grey + ' field needs to be defined in ' + 'package.json'.grey 
            # Special chars?
            if encodeURIComponent(pkg.author) isnt pkg.author
                throw 'author'.grey + ' field in ' + 'package.json'.grey + ' contains characters that are not allowed in a URL'
            pkg
    # App name field.
    ).then(
        (pkg) ->
            # Defined?
            unless pkg.name and pkg.name.length > 0
                throw 'name'.grey + ' field needs to be defined in ' + 'package.json'.grey 
            # Special chars?
            if encodeURIComponent(pkg.name) isnt pkg.name
                throw 'name'.grey + ' field in ' + 'package.json'.grey + ' contains characters that are not allowed in a URL'
            pkg
    # Start script field.
    ).then(
        (pkg) ->
            # Defined?
            unless pkg.scripts and pkg.scripts.start and pkg.scripts.start.length > 0
                throw 'scripts.start'.grey + ' field needs to be defined in ' + 'package.json'.grey 
            pkg
    # Pack the app directory and stream it to the server.
    ).then(
        (pkg) ->
            def = Q.defer()

            fstream.Reader({ 'path': APP_DIR, 'type': 'Directory' })
            .pipe(tar.Pack({ 'prefix': '.' }))
            .pipe(zlib.Gzip())
            .pipe(request.post({'url': "http://#{ukraine_ip}:9002/deploy/#{pkg.author}/#{pkg.name}"}, (err, res, body) ->
                if err then def.reject err
                else if res.statusCode isnt 200 then def.reject body
                else def.resolve pkg, body
            ))

            def.promise
    # OK or bust.
    ).then(
        (pkg, body) ->
            winston.info (pkg.author + '/' + pkg.name).grey + ' deployed ' + 'ok'.green.bold
        , (err) ->
            winston.error err
    )