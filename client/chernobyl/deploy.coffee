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
APP_DIR = '.'#'../example_app'
# Unfortunately, the haibu API only allows to stop apps by name, not by user too.
APP_USER = 'chernobyl'

# CLI output on the default output.
winston.cli()

# The actual task.
task.deploy = (ukraine_ip, cfg) ->
    # return fstream.Reader({ 'path': APP_DIR, 'type': 'Directory' })
    # .pipe(tar.Pack({ 'prefix': '.' }))
    # .pipe(zlib.Gzip())
    # .pipe(fstream.Writer({ 'path': 'app.tgz', 'type': 'File' }))

    # Read the app's `package.json` file.
    return Q.fcall( ->
        winston.debug 'Attempting to read ' + 'package.json'.grey + ' file'
        
        def = Q.defer()
        fs.readFile "#{APP_DIR}/package.json", 'utf-8', (err, text) ->
            if err then def.reject err
            else def.resolve text
        def.promise
    # JSON parse.
    ).when(
        (pkg) ->
            winston.debug 'Attempting to parse ' + 'package.json'.grey + ' file'

            JSON.parse pkg
    # App name field.
    ).when(
        (pkg) ->
            winston.debug 'Checking for ' + 'app'.grey + ' field in ' + 'package.json'.grey + ' file'

            # Defined?
            unless pkg.name and pkg.name.length > 0
                throw 'name'.grey + ' field needs to be defined in ' + 'package.json'.grey 
            # Special chars?
            if encodeURIComponent(pkg.name) isnt pkg.name
                throw 'name'.grey + ' field in ' + 'package.json'.grey + ' contains characters that are not allowed in a URL'
            pkg
    # Start script field.
    ).when(
        (pkg) ->
            winston.debug 'Checking for ' + 'scripts'.grey + ' field in ' + 'package.json'.grey + ' file'

            # Defined?
            unless pkg.scripts and pkg.scripts.start and pkg.scripts.start.length > 0
                throw 'scripts.start'.grey + ' field needs to be defined in ' + 'package.json'.grey 
            pkg
    # Is anyone listening?
    ).then(
        (pkg) ->
            winston.debug 'Is ' + 'haibu'.grey + ' up?'

            def = Q.defer()

            request.get {'url': "http://#{ukraine_ip}:#{cfg.haibu_port}/version"}, (err, res, body) ->
                if err
                    def.reject err
                else if res.statusCode isnt 200
                    def.reject body
                else
                    winston.info (JSON.parse(body)).version.grey + ' accepting connections'
                    def.resolve pkg

            def.promise
    # Is this app running already?
    ).then(
        (pkg) ->
            winston.debug 'Is ' + pkg.name.bold + ' running already?'

            def = Q.defer()

            request.get {'url': "http://#{ukraine_ip}:#{cfg.haibu_port}/drones/running"}, (err, res, body) ->
                if err then def.reject err
                else if res.statusCode isnt 200 then def.reject body
                else
                    # All the drones currently running.
                    drones = JSON.parse(body)
                    # Is our app running already?
                    for drone in drones
                        if drone.user is APP_USER and drone.name is pkg.name
                            winston.warn pkg.name.bold + ' exists already'
                            return def.resolve [ true, pkg ]

                    # All went fine.
                    def.resolve [ false, pkg ]

            def.promise
    # If we are passed an id of an app to stop, we will attempt to stop it.
    ).then(
        ([ stop, pkg ]) ->
            def = Q.defer()

            # Do we need to actually try the stopping?
            unless stop then def.resolve pkg
            else
                winston.info 'Trying to stop ' + pkg.name.bold

                request
                    'uri': "http://#{ukraine_ip}:#{cfg.haibu_port}/drones/#{pkg.name}/stop"
                    'method': 'POST'
                    'json':
                        'stop':
                            'name': pkg.name
                , (err, res, body) ->
                    if err then def.reject err
                    else if res.statusCode isnt 200 then def.reject body
                    else
                        def.resolve pkg

            def.promise
    # Pack the app directory and stream it to the server.
    ).then(
        (pkg) ->
            def = Q.defer()

            # Response handler.
            response = (err, res, body) ->
                if err then def.reject err
                else if res.statusCode isnt 200
                    # Is this the "incorrect header check" error?
                    if body.error.message is 'incorrect header check'
                        winston.warn 'Incorrect header check error, trying again'
                        # Stream again.
                        stream()
                    else
                        def.reject body
                else def.resolve pkg, body

            # Init streaming.
            stream = do ->
                winston.debug 'Sending ' + pkg.name.bold + ' to ' + 'haibu'.grey
                
                fstream.Reader({ 'path': APP_DIR, 'type': 'Directory' })
                .pipe(tar.Pack({ 'prefix': '.' }))
                .pipe(zlib.Gzip())
                .pipe(request.post({ 'url': "http://#{ukraine_ip}:#{cfg.haibu_port}/deploy/#{APP_USER}/#{pkg.name}" }, response))

            def.promise
    # OK or bust.
    ).done(
        (pkg, body) ->
            winston.info pkg.name.bold + ' deployed ' + 'ok'.green.bold
        , (err) ->
            winston.error err
    )