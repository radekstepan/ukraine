#!/usr/bin/env coffee
fs = require 'fs'
path = require 'path'
winston = require 'winston'

# CLI output on the default output.
winston.cli()

# We request the same file in the main thread.
cfg = JSON.parse fs.readFileSync(path.resolve(__dirname, '../config.json')).toString('utf-8')

haibu = require '../node_modules/haibu/lib/haibu.js' # direct path to local haibu!
_sendResponse = haibu.sendResponse

kgb = exports
kgb.name = 'kgb'
kgb.init = (done) -> done()

kgb.attach = ->
    # Override default sendResponse.
    haibu.sendResponse = (res, status, body) ->
        # Log it.
        winston.debug res.req.url

        # What kind of request was it?
        req = res.req.url.split('/')[1...]

        # Deploying.
        if req[0] is 'deploy'
            # Did we spawn a new drone?
            if status is 200 and body.drone?
                # Get the current routes.
                old = JSON.parse fs.readFileSync path.resolve(__dirname, 'routes.json')
                # Store the new routes here.
                nu = {}
                # Update to a new port?
                unless (do ->
                    found = false
                    for a, b in old.router
                        [ ip, name ] = a.split('/')
                        # A new port?
                        if name is body.drone.name
                            b = "#{ip}/#{body.drone.port}" ; found = true
                        # Save it.
                        nu[a] = b
                    found
                )
                    # Add a new route then mapping from the outside in.
                    nu["#{cfg.proxy_host}/#{body.drone.name}/"] = "127.0.0.1:#{body.drone.port}"

                # Write it.
                id = fs.openSync path.resolve(__dirname, 'routes.json'), 'w', 0o0666
                fs.writeSync id, JSON.stringify({'router': nu}), null, 'utf8'

        # Stopping.
        else if req[0] is 'drones' and req[2] is 'stop'
            # Get the current routes.
            old = JSON.parse fs.readFileSync path.resolve(__dirname, 'routes.json')
            # Store the new routes here.
            nu = {}
            # Remove the app if present.
            for a, b in old.router
                [ ip, name ] = a.split('/')
                # Save it unless it is our app.
                nu[a] = b unless name is req[1]

            # Write it.
            id = fs.openSync path.resolve(__dirname, 'routes.json'), 'w', 0o0666
            fs.writeSync id, JSON.stringify({'router': nu}), null, 'utf8'

        # Continue as before.
        _sendResponse.apply @, arguments