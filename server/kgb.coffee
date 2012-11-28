#!/usr/bin/env coffee
fs = require 'fs'
path = require 'path'

haibu = require '../node_modules/haibu/lib/haibu.js' # direct path to local haibu!
_sendResponse = haibu.sendResponse

kgb = exports
kgb.name = 'kgb'
kgb.init = (done) -> done()

kgb.attach = attach = ->
    # Override default sendResponse.
    haibu.sendResponse = sendResponse = (res, status, body) ->
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
                    [ ip, user, name ] = a.split('/')
                    # A new port?
                    if user is body.drone.user and name is body.drone.name
                        b = "#{ip}/#{body.drone.port}" ; found = true
                    # Save it.
                    nu[a] = b
                found
            )
                # Add a new route then.
                nu["127.0.0.1/#{body.drone.user}/#{body.drone.name}"] = "127.0.0.1:#{body.drone.port}"

            # Write it.
            id = fs.openSync path.resolve(__dirname, 'routes.json'), 'w', 0o0666
            fs.writeSync id, JSON.stringify({'router': nu}), null, 'utf8'
        else
            console.log body

        # Continue as before.
        _sendResponse.apply @, arguments