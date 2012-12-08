#!/usr/bin/env coffee
fs      = require 'fs'
path    = require 'path'
winston = require 'winston'
tar     = require 'tar'
zlib    = require 'zlib'
fstream = require 'fstream'
request = require 'request'
Q       = require 'q'

task = exports

# Unfortunately, the haibu API only allows to stop apps by name, not by user too.
APP_USER = 'chernobyl'

# CLI output on the default output.
winston.cli()

# The actual task.
task.deploy = (ukraine_ip, app_dir, cfg) ->
    # return fstream.Reader({ 'path': app_dir, 'type': 'Directory' })
    # .pipe(tar.Pack({ 'prefix': '.' }))
    # .pipe(zlib.Gzip())
    # .pipe(fstream.Writer({ 'path': 'app.tgz', 'type': 'File' }))

    # Read the app's `package.json` file.
    return Q.fcall( ->
        winston.debug 'Attempting to read ' + 'package.json'.grey + ' file'
        
        def = Q.defer()
        fs.readFile "#{app_dir}/package.json", 'utf-8', (err, text) ->
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

            request.get
                'url': "http://#{ukraine_ip}:#{cfg.haibu_port}/version"
                'headers':
                    'x-auth-token': cfg.auth_token
            , (err, res, body) ->
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

            # Response handler.
            response = (err, res, body) ->
                if err then def.reject err
                else if res.statusCode isnt 200
                    # Try JSON.
                    try
                        body = JSON.parse body
                        # Does it have a standard signature?
                        message = body?.error?.message or body
                        # Is this the "incorrect header check" error?
                        if message is 'incorrect header check'
                            winston.warn 'Incorrect header check error, trying again'
                            # Stream again.
                            stream()
                        else
                            def.reject JSON.stringify body
                    catch e
                        def.reject body
                else def.resolve pkg, body

            # Init streaming.
            stream = do ->
                winston.debug 'Sending ' + pkg.name.bold + ' to ' + 'haibu'.grey
                
                # Skip fils in `node_modules` directory.
                filter = (props) -> props.path.indexOf('/node_modules/') is -1

                fstream.Reader({ 'path': app_dir, 'type': 'Directory', 'filter': filter })
                .pipe(tar.Pack({ 'prefix': '.' }))
                .pipe(zlib.Gzip())
                .pipe(
                    request.post
                        'url': "http://#{ukraine_ip}:#{cfg.haibu_port}/drones/#{pkg.name}/deploy"
                        'headers':
                            'x-auth-token': cfg.auth_token
                    , response
                )

            def.promise
    # OK or bust.
    ).done(
        (pkg, body) ->
            winston.info pkg.name.bold + ' deployed ' + 'ok'.green.bold
        , (err) ->
            try
                winston.error (JSON.parse(err)).message
            catch e
                winston.error err
    )