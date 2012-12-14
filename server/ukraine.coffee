#!/usr/bin/env coffee
fs      = require 'fs'
path    = require 'path'
winston = require 'winston'
Q       = require 'q'

# CLI output on the default output.
winston.cli()

# Welcome header.
Q.fcall(
    ->
        def = Q.defer()

        winston.info "Welcome to #{'ukraine'.grey} comrade"

        fs.readFile path.resolve(__dirname, 'logo.txt'), (err, data) ->
            if err then def.reject err
            
            ( winston.help line.cyan.bold for line in data.toString('utf-8').split('\n') )

            winston.help ''
            winston.help 'Management of Node.js cloud apps'
            winston.help ''

            def.resolve()

        def.promise
# Load config.
).then(
    ->
        winston.debug 'Trying to load config'

        def = Q.defer()
        
        fs.readFile path.resolve(__dirname, '../config.json'), (err, data) ->
            if err then def.reject err
            try
                # JSON parse.
                cfg = JSON.parse data
                # Add defaults.
                cfg.proxy_hostname_only ?= false
                # Resolve.
                def.resolve cfg
            catch e
                def.reject e.message

        def.promise
# Do we need to init routing and env tables?
).then(
    (cfg) ->
        winston.debug 'Creating new routing and env table?'

        routes = Q.fcall( ->
            def = Q.defer()
            fs.exists p = path.resolve(__dirname, './routes.json'), (exists) ->
                unless exists
                    fs.writeFile p, '{}', (err) ->
                        if err then def.reject err
                        else def.resolve cfg
                else def.resolve cfg
            def.promise
        )

        env = Q.fcall( ->
            def = Q.defer()
            fs.exists p = path.resolve(__dirname, './env.json'), (exists) ->
                unless exists
                    fs.writeFile p, JSON.stringify({ 'router': {}, 'hostnameOnly': cfg.proxy_hostname_only }, null, 4), (err) ->
                        if err then def.reject err
                        else def.resolve cfg
                else def.resolve cfg
            def.promise
        )

        Q.all [ routes, env ]
# Spawn proxy.
).when(
    ( [ cfg ] ) ->
        winston.debug 'Trying to spawn proxy server'

        proxy = require 'http-proxy'

        # Create a proxy server listening on port 80 routing to apps in a dynamic `routes` file.
        proxy.createServer('router': path.resolve(__dirname, './routes.json')).listen(cfg.proxy_port)

        cfg
# Custom haibu plugins.
).when(
    (cfg) ->
        winston.debug 'Trying to use custom haibu plugins'

        haibu = require '../node_modules/haibu/lib/haibu.js' # direct path to local haibu!

        # Inject our own plugins.
        for plugin in [ 'ducktape' ]
            haibu.__defineGetter__ plugin, -> require path.resolve(__dirname, "#{plugin}.coffee")
            haibu.use(haibu[plugin], {})

        [ cfg, haibu ]
# Spawn haibu.
).then(
    ([ cfg, haibu ]) ->
        winston.debug 'Trying to start haibu drone'

        def = Q.defer()

        # Create the hive on port 9002.
        haibu.drone.start
            'env': 'development'
            'port': cfg.haibu_port
            'host': '127.0.0.1'
        , ->
            def.resolve [ cfg, haibu ]

        def.promise
).then(
    ([ cfg, haibu ]) ->
        # Following will be monkey patching the router with our own functionality.
        winston.debug 'Adding custom routes'

        def = Q.defer()

        # Remove all the original routes.
        haibu.router.routes = {}

        fs.readdir path.resolve(__dirname, './ukraine/'), (err, files) ->
            if err then def.reject err
            else
                ( require './ukraine/' + file for file in files )
                def.resolve [ cfg, haibu ]

        def.promise
# See which apps have been re-spawned from a previous session and update our routes.
).then(
    ([ cfg, haibu ]) ->
        winston.debug 'Updating proxy routing table'

        # Traverse running apps.
        table = {}
        save = (app_name, app_port) ->
            # Are we using non standard port? Else leave it out.
            port = (if (cfg.proxy_port isnt 80) then ':' + cfg.proxy_port else '') + '/'
            # 'Hostname Only' ProxyTable?
            if cfg.proxy_hostname_only?
                table["#{app_name}.#{cfg.proxy_host}#{port}"] = "127.0.0.1:#{app_port}"
            else
                table["#{cfg.proxy_host}#{port}#{app_name}/"] = "127.0.0.1:#{app_port}"
        ( save(app.name, app.port) for app in haibu.running.drone.running() )

        def = Q.defer()

        # Write the routing table.
        fs.writeFile path.resolve(__dirname, 'routes.json'), JSON.stringify({ 'router': table, 'hostnameOnly': cfg.proxy_hostname_only }, null, 4), (err) ->
            if err then def.reject err.message
            else def.resolve cfg

        def.promise
# OK or bust.
).done(
    (cfg) ->
        # We done.
        winston.info 'haibu'.grey + ' listening on port ' + new String(cfg.haibu_port).bold
        winston.info 'http-proxy'.grey + ' listening on port ' + new String(cfg.proxy_port).bold
        winston.info 'cloud apps live in ' + path.resolve(__dirname, '../node_modules/haibu/local').bold
        winston.info 'ukraine'.grey + ' started ' + 'ok'.green.bold
    , (err) ->
        winston.error err.message or err
)