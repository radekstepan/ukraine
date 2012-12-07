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

# Unfortunately, the haibu API only allows to stop apps by name, not by user too.
APP_USER = 'chernobyl'

# CLI output on the default output.
winston.cli()

# The actual task.
task.env = (ukraine_ip, app_dir, key_value, cfg) ->
    # Set it 'glob', am not going to be passing them round like a dick.
    key = '' ; value = ''

    # Checking env var format.
    return Q.fcall( ->
        winston.debug 'Checking the env format'

        key_value = key_value.split('=')
        throw 'Needs to have delimiting = character' unless key_value.length > 1

        # Pop the key and value off.
        key = key_value.reverse().pop()
        # Join on any extra equal signs.
        value = key_value.reverse().join('=')
    # Read the app's `package.json` file.
    ).then( ->
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

            request.get {'url': "http://#{ukraine_ip}:#{cfg.haibu_port}/version"}, (err, res, body) ->
                if err
                    def.reject err
                else if res.statusCode isnt 200
                    def.reject body
                else
                    winston.info (JSON.parse(body)).version.grey + ' accepting connections'
                    def.resolve pkg

            def.promise
    # Attempt to pass env vars.
    ).then(
        (pkg) ->
            def = Q.defer()

            winston.info 'Trying to send env var for ' + pkg.name.bold

            request
                'uri': "http://#{ukraine_ip}:#{cfg.haibu_port}/env/#{APP_USER}/#{pkg.name}"
                'method': 'POST'
                # The data to send.
                'json':
                    'key': key
                    'value': value
            , (err, res, body) ->
                if err then def.reject err
                else if res.statusCode isnt 200 then def.reject body?.error?.message or body
                else
                    def.resolve pkg

            def.promise
    # Check that the app is running again.
    ).then(
        (pkg) ->
            winston.debug 'Is ' + pkg.name.bold + ' running again?'

            def = Q.defer()

            request.get {'url': "http://#{ukraine_ip}:#{cfg.haibu_port}/drones/#{pkg.name}"}, (err, res, body) ->
                if err then def.reject err
                else if res.statusCode isnt 200 then def.reject body
                else def.resolve pkg

            def.promise
    # OK or bust.
    ).done(
        (pkg, body) ->
            winston.info 'Environment variable ' + key.bold  + ' for ' + pkg.name.bold + ' set ' + 'ok'.green.bold
        , (err) ->
            winston.error err
    )