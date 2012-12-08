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
    
    # Deploying app.
    return Q.fcall( ->
        winston.debug 'Deploying app'

        def = Q.defer()

        haibu.running.drone.deploy APP_USER, APP_NAME, req, (err, result) ->
            if err then def.reject err
            else def.resolve result.port

        def.promise
    # Update the routing table.
    ).then(
        (port) ->
            winston.debug 'Updating routing table'

            routes = path.resolve(__dirname, '../routes.json')

            # Get the current routes.
            old = JSON.parse fs.readFileSync routes
            # Store the new routes here.
            nu = {}
            # Update to a new port?
            unless (do ->
                found = false
                for a, b in old.router
                    [ ip, name ] = a.split('/')
                    # A new port?
                    if name is APP_NAME
                        b = "#{ip}/#{port}" ; found = true
                    # Save it.
                    nu[a] = b
                found
            )
                # Add a new route then mapping from the outside in.
                nu["#{CFG.proxy_host}/#{APP_NAME}/"] = "127.0.0.1:#{port}"

            # Write it.
            id = fs.openSync routes, 'w', 0o0666
            fs.writeSync id, JSON.stringify({'router': nu}), null, 'utf8'
    # OK or bust.
    ).done(
        ->
            haibu.sendResponse res, 200, {}
        , (err) ->
            haibu.sendResponse res, 500,
                'error':
                    'message': err.message or err
    )