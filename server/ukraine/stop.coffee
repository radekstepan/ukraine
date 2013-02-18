#!/usr/bin/env coffee
fs      = require 'fs'
path    = require 'path'
winston = require 'winston'
Q       = require 'q'

haibu = require '../../node_modules/haibu/lib/haibu.js' # direct path to local haibu!

# We request the same file in the main thread.
CFG = JSON.parse fs.readFileSync(path.resolve(__dirname, '../../config.json')).toString('utf-8')

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

            routes = path.resolve(__dirname, '../routes.json')

            # Get the current routes.
            Q.fcall( ->
                def = Q.defer()

                fs.readFile routes, (err, data) ->
                    if err then def.reject err
                    def.resolve JSON.parse data

                def.promise
            # Update.
            ).then(
                (old) ->
                    # Store the new routes here.
                    rtr = {} ; dead_port = null
                    # Remove the app if present.
                    for external, internal of old.router
                        # Proxy hostname only?
                        if CFG.proxy_hostname_only
                            unless external.split('.')[0] is APP_NAME
                                rtr[external] = internal
                            else
                                dead_port = internal.split(':')[1]
                        # Subdirectory based.
                        else
                            # Save it unless it is our app?
                            unless external.split('/')[1] is APP_NAME
                                rtr[external] = internal
                            else
                                dead_port = internal.split(':')[1]
                    
                    # Was this app a root app?
                    if CFG.root_app and CFG.root_app is APP_NAME
                        # Find and remove the root app entry too.
                        for external, internal of rtr
                            if internal.split(':')[1] is dead_port
                                delete rtr[external]

                    rtr
            # Write it.
            ).when(
                (rtr) ->
                    def = Q.defer()
                    fs.writeFile routes, JSON.stringify({'router': rtr}, null, 4), (err) ->
                        if err then def.reject err
                        else def.resolve()
                    def.promise
            )
    # OK or bust.
    ).done(
        ->
            haibu.sendResponse res, 200, {}
        , (err) ->
            haibu.sendResponse res, 500,
                'error':
                    'message': err.message or err
    )