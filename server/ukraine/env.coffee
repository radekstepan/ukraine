#!/usr/bin/env coffee
fs      = require 'fs'
path    = require 'path'
winston = require 'winston'
Q       = require 'q'
wrench  = require 'wrench'

haibu = require '../../node_modules/haibu/lib/haibu.js' # direct path to local haibu!

# We request the same file in the main thread.
CFG = JSON.parse fs.readFileSync(path.resolve(__dirname, '../../config.json')).toString('utf-8')

# Haibu only knows apps by name.
APP_USER = 'chernobyl'

# POST environment variables and restart the app with this new information.
haibu.router.post '/env/:name', {} , (APP_NAME) ->
    req = @req ; res = @res
    
    # Good headers?
    return Q.fcall( ->            
        throw 'Incorrect content-type, send JSON' unless req.request.headers['content-type'] is 'application/json'
    # Correct format?
    ).when(
        ->
            throw 'Incorrect {key: "", value: ""} format' unless req.body.key and req.body.value
    # Set in a file.
    ).when(
        ->
            # Get the file.
            env = JSON.parse fs.readFileSync p = path.resolve(__dirname, '../env.json')
            
            # Set the new value.
            env[APP_USER] ?= {}
            env[APP_USER][APP_NAME] ?= {}
            env[APP_USER][APP_NAME][req.body.key] = req.body.value

            # Write it.
            id = fs.openSync p, 'w', 0o0666
            fs.writeSync id, JSON.stringify(env), null, 'utf8'
    # Get the hash and package dir of the running app.
    ).then(
        ->            
            for app in haibu.running.drone.running()
                if app.user is APP_USER and app.name is APP_NAME
                    return [ app.hash, haibu.running.drone.show(APP_NAME).app.directories.home ]
    # Stop the app.
    ).when(
        ([ hash, dir ]) ->
            def = Q.defer()

            haibu.running.drone.stop APP_NAME, (err, result) ->
                if err then def.reject err
                else def.resolve [ hash, dir ]

            def.promise
    # Get the app's `package.json` file and form an app object.
    ).then(
        ([ hash, dir ]) ->
            # Resolve path.
            dir = path.resolve __dirname, '../../node_modules/haibu/packages/' + dir

            # Read `package.json`.
            pkg = JSON.parse fs.readFileSync(dir + '/package.json')

            # Merge in properties.
            pkg.user = APP_USER
            pkg.hash = hash
            pkg.repository = 'type': 'local', 'directory': dir

            pkg
    # Deploy it anew.
    ).when(
        (pkg) ->
            def = Q.defer()

            haibu.running.drone.start pkg, (err, result) ->
                if err then def.reject err
                else def.resolve()

            def.promise
    # Get the new app's port.
    ).then(
        ->
            # Find the new port in the running apps.
            for app in haibu.running.drone.running()
                if app.user is APP_USER and app.name is APP_NAME
                    return app.port
    # Update the route to the app with the new port.
    ).when(
        (port) ->
            # Get the current routes.
            old = JSON.parse fs.readFileSync p = path.resolve(__dirname, '../routes.json')
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
            id = fs.openSync p, 'w', 0o0666
            fs.writeSync id, JSON.stringify({'router': nu}), null, 'utf8'
    # OK or bust.
    ).done(
        ->
            haibu.sendResponse res, 200, {}
        , (err) ->
            haibu.sendResponse res, 500,
                'error':
                    'message': err.message
    )