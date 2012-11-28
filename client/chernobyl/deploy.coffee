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
    # User field.
    ).then(
        (pkg) ->
            # Defined?
            unless pkg.user and pkg.user.length > 0
                throw 'user'.grey + ' field needs to be defined in ' + 'package.json'.grey 
            # Special chars?
            if encodeURIComponent(pkg.user) isnt pkg.user
                throw 'user'.grey + ' field in ' + 'package.json'.grey + ' contains characters that are not allowed in a URL'
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
    # Is anyone listening?
    ).then(
        (pkg) ->
            def = Q.defer()

            request.get {'url': "http://#{ukraine_ip}:9002/version"}, (err, res, body) ->
                if err
                    def.reject err
                else if res.statusCode isnt 200
                    def.reject body
                else
                    winston.info (JSON.parse(body)).version.grey + ' accepting connections'
                    def.resolve pkg

            def.promise
    # Pack the app directory and stream it to the server.
    ).then(
        (pkg) ->
            def = Q.defer()

            fstream.Reader({ 'path': APP_DIR, 'type': 'Directory' })
            .pipe(tar.Pack({ 'prefix': '.' }))
            .pipe(zlib.Gzip())
            .pipe(request.post({'url': "http://#{ukraine_ip}:9002/deploy/#{pkg.user}/#{pkg.name}"}, (err, res, body) ->
                if err then def.reject err
                else if res.statusCode isnt 200 then def.reject body
                else def.resolve pkg, body
            ))

            def.promise
    # OK or bust.
    ).then(
        (pkg, body) ->
            winston.info (pkg.user + '/' + pkg.name).grey + ' deployed ' + 'ok'.green.bold
        , (err) ->
            winston.error err
    )