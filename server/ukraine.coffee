#!/usr/bin/env coffee
fs      = require 'fs'
path    = require 'path'
winston = require 'winston'
Q       = require 'q'

# CLI output on the default output.
winston.cli()

# Load config.
winston.debug 'Loading config'
module.exports.cfg = cfg = require path.resolve __dirname, '../config.json'

# Load the router and make it available for everyone else.
winston.debug 'Loading router'
Router = require path.resolve __dirname, './ukraine/router.coffee'
module.exports.router = router = new Router path.resolve __dirname, './routes.json'

# Welcome header.
Q.fcall(
    ->
        def = Q.defer()

        winston.info "Welcome to #{'ukraine'.grey} comrade"

        fs.readFile path.resolve(__dirname, 'logo.txt'), (err, data) ->
            if err then def.reject err
            
            ( winston.help line.cyan.bold for line in data.toString('utf8').split('\n') )

            winston.help ''
            winston.help 'Management of Node.js cloud apps'
            winston.help ''

            def.resolve()

        def.promise

# Check Node.js version.
).then(
    ->
        winston.debug 'Checking version of Node.js'
        unless /^v0.8./.test process.version
            throw "Node.js v0.8.x is allowed only, not #{process.version.bold}"

# Create log directory?
).then(
    ->
        winston.debug 'Creating log directory?'

        def = Q.defer()
        fs.mkdir path.resolve(__dirname, './logs'), (err) ->
            if err and err.code isnt 'EEXIST' then def.reject(err) else def.resolve()
        def.promise

# Do we need to init env table?
).then(
    ->
        winston.debug 'Creating env table?'

        def = Q.defer()
        fs.exists p = path.resolve(__dirname, './env.json'), (exists) ->
            unless exists
                fs.writeFile p, '{}', (err) ->
                    if err then def.reject err
                    else def.resolve()
            else def.resolve()
        def.promise

# Spawn proxy.
).when(
    ->
        winston.debug 'Trying to spawn proxy server'

        proxy = require 'http-proxy'

        # Create a proxy server.
        proxy.createServer(router.route).listen(cfg.proxy_port)
# Spawn haibu.
).then(
    ->
        winston.debug 'Trying to start haibu drone'

        def = Q.defer()

        # Be sure this is our version of haibu!
        haibu = require path.resolve __dirname, '../node_modules/haibu/lib/haibu.js'

        # Create the hive on port 9002.
        haibu.drone.start
            'env': 'development'
            'port': cfg.haibu_port
            'host': '127.0.0.1'
        , ->
            def.resolve haibu

        def.promise
).then(
    (haibu) ->
        # Following will be monkey patching the router with our own functionality.
        winston.debug 'Adding custom routes'

        def = Q.defer()

        # Remove all the original routes.
        haibu.router.routes = {}

        fs.readdir path.resolve(__dirname, './ukraine/'), (err, files) ->
            if err then def.reject err
            else
                ( require './ukraine/' + file for file in files )
                def.resolve haibu

        def.promise

# See which apps have been re-spawned from a previous session and update our routes.
).then(
    (haibu) ->
        winston.debug 'Updating proxy routing table'

        ( router.update(app.name, app.port) for app in haibu.running.drone.running() )

        # Async write the router.
        def = Q.defer()
        router.write (err) ->
            if err then def.reject err
            else def.resolve()
        def.promise

# OK or bust.
).done(
    ->
        # We done.
        winston.info 'haibu'.grey + ' listening on port ' + new String(cfg.haibu_port).bold
        winston.info 'http-proxy'.grey + ' listening on port ' + new String(cfg.proxy_port).bold
        winston.info 'cloud apps live in ' + path.resolve(__dirname, '../node_modules/haibu/local').bold
        winston.info 'ukraine'.grey + ' started ' + 'ok'.green.bold
    , (err) ->
        winston.error err.message or err
        process.exit(1)
)