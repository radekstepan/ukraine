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

# POST environment variables and restart the app with this new information.
haibu.router.post '/env/:name', {} , (APP_NAME) ->
    req = @req ; res = @res
    
    # Good headers?
    return Q.fcall( ->
        winston.debug 'Checking for JSON content-type'
        throw 'Incorrect content-type, send JSON' unless req.request.headers['content-type'] is 'application/json'
    
    # Correct format?
    ).then(
        ->
            winston.debug 'Checking request format'
            throw 'Incorrect {key: "", value: ""} format' unless req.body.key and req.body.value
    
    # Set in a file.
    ).when(
        ->
            winston.debug 'Setting property in local env file.'

            # Get the file.
            Q.fcall( ->
                def = Q.defer()

                fs.readFile p = path.resolve(__dirname, '../env.json'), (err, data) ->
                    if err then def.reject err
                    env = JSON.parse data

                    # Set the new value.
                    env[APP_USER] ?= {}
                    env[APP_USER][APP_NAME] ?= {}
                    env[APP_USER][APP_NAME][req.body.key] = req.body.value

                    def.resolve [ p, env ]

                def.promise
            # Write it.
            ).when(
                ([ p, env ]) ->
                    def = Q.defer()
                    fs.writeFile p, JSON.stringify(env, null, 4), (err) ->
                        if err then def.reject err
                        else def.resolve()
                    def.promise
            )
    
    # Get the hash and package dir of the running app.
    ).then(
        ->
            winston.debug 'Getting apps\'s package dir and hash'

            for app in haibu.running.drone.running()
                if app.user is APP_USER and app.name is APP_NAME
                    return [ app.hash, haibu.running.drone.show(APP_NAME).app.directories.home ]
    
    # Stop the app.
    ).when(
        ([ hash, dir ]) ->
            winston.debug 'Stopping app'

            def = Q.defer()

            haibu.running.drone.stop APP_NAME, (err, result) ->
                if err then def.reject err
                else def.resolve [ hash, dir ]

            def.promise
    
    # Get the app's `package.json` file and form an app object.
    ).then(
        ([ hash, dir ]) ->
            winston.debug 'Forming new app object'

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
            winston.debug 'Starting app anew'

            def = Q.defer()

            haibu.running.drone.start pkg, (err, result) ->
                if err then def.reject err
                else def.resolve()

            def.promise
    
    # Get the new app's port.
    ).then(
        ->
            winston.debug 'Getting deployed app\'s new port'

            # Find the new port in the running apps.
            for app in haibu.running.drone.running()
                if app.user is APP_USER and app.name is APP_NAME
                    return app.port
    
    # Update the route to the app with the new port.
    ).when(
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