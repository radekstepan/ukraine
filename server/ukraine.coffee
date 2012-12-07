#!/usr/bin/env coffee
fs      = require 'fs'
path    = require 'path'
winston = require 'winston'
Q       = require 'q'
wrench  = require 'wrench'

# CLI output on the default output.
winston.cli()

winston.info "Welcome to #{'ukraine'.grey} comrade"

# Show welcome logo and desc.
( winston.help line.cyan.bold for line in fs.readFileSync(path.resolve(__dirname, 'logo.txt')).toString('utf-8').split('\n') )
winston.help ''
winston.help 'Management of Node.js cloud apps'
winston.help ''

haibu = require '../node_modules/haibu/lib/haibu.js' # direct path to local haibu!
proxy = require 'http-proxy'

winston.debug 'Trying to load config'

# Load config.
try
    cfg = JSON.parse fs.readFileSync(path.resolve(__dirname, '../config.json')).toString('utf-8')
catch e
    return winston.error e.message

winston.debug 'Trying to spawn proxy server'

# Create a proxy server listening on port 80 routing to apps in a dynamic `routes` file.
proxy.createServer('router': path.resolve(__dirname, 'routes.json')).listen(cfg.proxy_port)

# Inject our own plugins.
for plugin in [ 'kgb', 'ducktape' ]
    haibu.__defineGetter__ plugin, -> require path.resolve(__dirname, "#{plugin}.coffee")

winston.debug 'Trying to use custom haibu plugins'

# Use these plugins.
( haibu.use(haibu[plugin], {}) for plugin in [ 'advanced-replies', 'kgb', 'ducktape' ] )

winston.debug 'Trying to start haibu drone'

# Create the hive on port 9002.
haibu.drone.start
    'env': 'development'
    'port': cfg.haibu_port
    'host': '127.0.0.1'
, ->
    # Following will be monkey patching the router with our own functionality.
    winston.debug 'Monkey patching custom haibu routes'

    # POST environment variables and restart the app with this new information.
    haibu.router.post '/env/:userid/:appid', {} , (user_id, app_id) ->
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
                env = JSON.parse fs.readFileSync p = path.resolve(__dirname, 'env.json')
                
                # Set the new value.
                env[user_id] ?= {}
                env[user_id][app_id] ?= {}
                env[user_id][app_id][req.body.key] = req.body.value

                # Write it.
                id = fs.openSync p, 'w', 0o0666
                fs.writeSync id, JSON.stringify(env), null, 'utf8'
        # Get the hash of the running app.
        ).then(
            ->
                for app in haibu.running.drone.running()
                    if app.user is user_id and app.name is app_id
                        return app.hash
        # Stop the app.
        ).when(
            (hash) ->
                def = Q.defer()

                haibu.running.drone.stop app_id, (err, result) ->
                    if err then def.reject err
                    else def.resolve hash

                def.promise
        # Get the app's latest package path.
        ).then(
            (hash) ->
                # Path to packages.
                p = path.resolve __dirname, '../node_modules/haibu/packages/'

                i = 0
                # Read the packages.
                for a in wrench.readdirSyncRecursive(p)
                    # Just top level dirs please.
                    if a.split('/').length is 1
                        # Now split on our name and get the number of ms.
                        [ b, time ] = a.split "#{user_id}-#{app_id}"
                        if time.length is 14
                            # Save the highest amount.
                            if (ms = parseInt(time[1...])) > i then i = ms

                [ "#{p}/#{user_id}-#{app_id}-#{i}", hash ]
        # Get the app's `package.json` file and form an app object.
        ).then(
            ([ dir, hash ]) ->
                pkg = JSON.parse fs.readFileSync(dir + '/package.json')

                pkg.user = user_id
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
                    if app.user is user_id and app.name is app_id
                        return app.port
        # Update the route to the app with the new port.
        ).when(
            (port) ->
                # Get the current routes.
                old = JSON.parse fs.readFileSync p = path.resolve(__dirname, 'routes.json')
                # Store the new routes here.
                nu = {}
                # Update to a new port?
                unless (do ->
                    found = false
                    for a, b in old.router
                        [ ip, name ] = a.split('/')
                        # A new port?
                        if name is app_id
                            b = "#{ip}/#{port}" ; found = true
                        # Save it.
                        nu[a] = b
                    found
                )
                    # We request the same file in the main thread.
                    cfg = JSON.parse fs.readFileSync(path.resolve(__dirname, '../config.json')).toString('utf-8')
                    
                    # Add a new route then mapping from the outside in.
                    nu["#{cfg.proxy_host}/#{app_id}/"] = "127.0.0.1:#{port}"

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

    # We done.
    winston.info 'haibu'.grey + ' listening on port ' + new String(cfg.haibu_port).bold
    winston.info 'http-proxy'.grey + ' listening on port ' + new String(cfg.proxy_port).bold
    winston.info 'cloud apps live in ' + path.resolve(__dirname, '../node_modules/haibu/local').bold