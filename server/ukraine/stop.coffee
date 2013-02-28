#!/usr/bin/env coffee
fs      = require 'fs'
path    = require 'path'
winston = require 'winston'
Q       = require 'q'

haibu = require '../../node_modules/haibu/lib/haibu.js' # direct path to local haibu!

# Path to our router.
{ router } = require path.resolve __dirname, '../ukraine.coffee'

# POST stop a running drone.
haibu.router.post '/drones/:name/stop', {} , (APP_NAME) ->
    req = @req ; res = @res
    
    # Stopping app.
    return Q.fcall( ->
        winston.debug 'Stopping app'

        def = Q.defer()

        haibu.running.drone.stop APP_NAME, (err, result) ->
            if err then def.reject err
            else def.resolve()

        def.promise
    
    # Update the routing table.
    ).then(
        ->
            winston.debug 'Updating proxy routes'

            def = Q.defer()

            router.update APP_NAME
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