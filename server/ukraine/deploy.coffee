#!/usr/bin/env coffee
fs      = require 'fs'
path    = require 'path'
winston = require 'winston'
Q       = require 'q'

haibu = require '../../node_modules/haibu/lib/haibu.js' # direct path to local haibu!

# Path to our router.
{ router } = require path.resolve __dirname, '../ukraine.coffee'

# Haibu only knows apps by name.
APP_USER = 'chernobyl'

# POST deploy an app.
haibu.router.post '/drones/:name/deploy', { 'stream': true } , (APP_NAME) ->
    req = @req ; res = @res
    
    # Stop the app if running already.
    return Q.fcall( ->
        def = Q.defer()

        winston.debug 'Is app running already?'

        # Find us in running apps maybe?
        return def.resolve() unless ( do ->
            for app in haibu.running.drone.running()
                return true if app.name is APP_NAME
        )

        winston.debug 'Stopping app'

        haibu.running.drone.stop APP_NAME, (err, result) ->
            if err then def.reject err
            else def.resolve()

        def.promise
   
    # Deploying app.
    ).when(
        ->
            winston.debug 'Deploying app'

            def = Q.defer()

            haibu.running.drone.deploy APP_USER, APP_NAME, req, (err, result) ->
                if err then def.reject err
                else def.resolve result.port

            def.promise
    
    # Update the routing table.
    ).then(
        (port) ->
            winston.debug 'Updating proxy routes'

            def = Q.defer()

            router.update APP_NAME, port
            router.write (err) ->
                if err then def.reject err
                else def.resolve()

            def.promise

    # OK or bust.
    ).done(
        ->
            haibu.sendResponse res, 200, {}
        , (err) ->
            haibu.sendResponse res, 500,
                'error':
                    'message': err.message or err
    )