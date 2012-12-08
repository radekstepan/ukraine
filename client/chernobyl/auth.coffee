#!/usr/bin/env coffee
fs      = require 'fs'
winston = require 'winston'
request = require 'request'
Q       = require 'q'

task = exports

# This is where this user stores their auth token.
TOKEN_PATH = process.env.HOME + '/.chernobyl'

# CLI output on the default output.
winston.cli()

# The actual task.
task.auth = (ukraine_ip, auth_token, cfg) ->
    return Q.fcall( ->
        winston.debug 'Attempting to write into ' + '.chernobyl'.grey + ' file'
        fs.writeFileSync TOKEN_PATH, auth_token
    # Try to auth with ukraine.
    ).when(
        ->
            winston.debug 'Is ' + 'haibu'.grey + ' up and accepting our token?'

            def = Q.defer()

            request.get
                'url': "http://#{ukraine_ip}:#{cfg.haibu_port}/version"
                'headers':
                    'x-auth-token': auth_token
            , (err, res, body) ->
                # Server down?
                if err then def.reject err
                # Bad token probably.
                else if res.statusCode isnt 200 then def.reject body
                # All good.
                else
                    winston.info (JSON.parse(body)).version.grey + ' accepting connections using our token'
                    def.resolve()

            def.promise
    # OK or bust.
    ).done(
        ->
            winston.info 'Auth key saved ' + 'ok'.green.bold
        , (err) ->
            try
                winston.error (JSON.parse(err)).message
            catch e
                winston.error err
    )