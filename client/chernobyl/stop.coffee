#!/usr/bin/env coffee
fs      = require 'fs'
winston = require 'winston'
request = require 'request'
Q       = require 'q'

task = exports

# CLI output on the default output.
winston.cli()

# The actual task.
task.stop = (ukraine_ip, app_dir, cfg) ->
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
    # Attempt to stop the app.
    ).then(
        (pkg) ->
            def = Q.defer()

            winston.info 'Trying to stop ' + pkg.name.bold

            request
                'uri': "http://#{ukraine_ip}:#{cfg.haibu_port}/drones/#{pkg.name}/stop"
                'method': 'POST'
                'headers':
                    'x-auth-token': cfg.auth_token
            , (err, res, body) ->
                if err then def.reject err
                else if res.statusCode isnt 200 then def.reject body?.error?.message or body
                else
                    def.resolve pkg

            def.promise
    # We do not trust what haibu says...
    ).then(
        (pkg) ->
            winston.debug 'Is ' + pkg.name.bold + ' still running?'

            def = Q.defer()

            request.get
                'url': "http://#{ukraine_ip}:#{cfg.haibu_port}/drones/#{pkg.name}"
                'headers':
                    'x-auth-token': cfg.auth_token
            , (err, res, body) ->
                if err then def.reject err
                else if res.statusCode isnt 404 then def.reject body
                else def.resolve pkg

            def.promise
    # OK or bust.
    ).done(
        (pkg, body) ->
            winston.info pkg.name.bold + ' stopped ' + 'ok'.green.bold
        , (err) ->
            try
                winston.error (JSON.parse(err)).message
            catch e
                winston.error err
    )