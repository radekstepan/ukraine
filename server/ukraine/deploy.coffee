#!/usr/bin/env coffee
fs      = require 'fs'
path    = require 'path'
winston = require 'winston'
Q       = require 'q'

haibu = require '../../node_modules/haibu/lib/haibu.js' # direct path to local haibu!

# We request the same file in the main thread.
CFG = JSON.parse fs.readFileSync(path.resolve(__dirname, '../../config.json')).toString('utf-8')

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
                    rtr = {}
                    # Update to a new port?
                    unless (do ->
                        found = false
                        for external, internal of old.router
                            # A new port?
                            if external.split('/')[1] is APP_NAME
                                internal = "127.0.0.1:#{port}" ; found = true
                            # Save it back.
                            rtr[external] = internal
                        found
                    )
                        # Are we using non standard port? Else leave it out.
                        p = (if (CFG.proxy_port isnt 80) then ":#{CFG.proxy_port}/" else '')
                        
                        # 'Hostname Only' ProxyTable?
                        if CFG.proxy_hostname_only
                            rtr["#{APP_NAME}.#{CFG.proxy_host}#{p}"] = "127.0.0.1:#{port}"
                            # Root app defined?
                            if CFG.root_app and CFG.root_app is APP_NAME
                                rtr["#{CFG.proxy_host}#{p}"] = "127.0.0.1:#{port}"
                        else
                            rtr["#{CFG.proxy_host}#{p}#{APP_NAME}/"] = "127.0.0.1:#{port}"
                    
                    rtr
            # Write it.
            ).when(
                (rtr) ->
                    def = Q.defer()
                    fs.writeFile routes, JSON.stringify({ 'router': rtr, 'hostnameOnly': CFG.proxy_hostname_only }, null, 4), (err) ->
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