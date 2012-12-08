#!/usr/bin/env coffee
fs      = require 'fs'
path    = require 'path'
winston = require 'winston'
Q       = require 'q'

haibu = require '../../node_modules/haibu/lib/haibu.js' # direct path to local haibu!

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
            winston.debug 'Updating routing table'

            routes = path.resolve(__dirname, '../routes.json')

            # Get the current routes.
            old = JSON.parse fs.readFileSync routes
            # Store the new routes here.
            rtr = {}
            # Remove the app if present.
            for external, internal of old.router
                # Save it unless it is our app.
                rtr[external] = internal unless external.split('/')[1] is APP_NAME

            # Write it.
            id = fs.openSync routes, 'w', 0o0666
            fs.writeSync id, JSON.stringify({'router': rtr}, null, 4), null, 'utf8'
    # OK or bust.
    ).done(
        ->
            haibu.sendResponse res, 200, {}
        , (err) ->
            haibu.sendResponse res, 500,
                'error':
                    'message': err.message or err
    )