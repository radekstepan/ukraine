#!/usr/bin/env coffee
fs      = require 'fs'
path    = require 'path'
winston = require 'winston'
Q       = require 'q'

# CLI output on the default output.
winston.cli()

haibu = require '../node_modules/haibu/lib/haibu.js' # direct path to local haibu!
proxy = require 'http-proxy'

# Load config.
try
    cfg = JSON.parse fs.readFileSync(path.resolve(__dirname, '../config.json')).toString('utf-8')
catch e
    return winston.error e.message

# Create a proxy server listening on port 80 routing to apps in a dynamic `routes` file.
proxy.createServer('router': path.resolve(__dirname, 'routes.json')).listen(cfg.proxy_port)

# Inject our own plugins.
for plugin in [ 'kgb', 'ducktape' ]
    haibu.__defineGetter__ plugin, -> require path.resolve(__dirname, "#{plugin}.coffee")

# Use these plugins.
( haibu.use(haibu[plugin], {}) for plugin in [ 'advanced-replies', 'kgb', 'ducktape' ] )

winston.info "Welcome to #{'ukraine'.grey} comrade"

# Show welcome logo and desc.
( winston.help line.cyan.bold for line in fs.readFileSync(path.resolve(__dirname, 'logo.txt')).toString('utf-8').split('\n') )
winston.help ''
winston.help 'Management of Node.js cloud apps'
winston.help ''

# Create the hive on port 9002.
haibu.drone.start
    'env': 'development'
    'port': cfg.haibu_port
    'host': '127.0.0.1'
, ->
    winston.info 'haibu'.grey + ' listening on port ' + new String(cfg.haibu_port).bold
    winston.info 'http-proxy'.grey + ' listening on port ' + new String(cfg.proxy_port).bold
    winston.info 'cloud apps live in ' + path.resolve(__dirname, '../node_modules/haibu/local').bold

    # Following will be monkey patching the router with our own functionality.

    # POST environment variables.
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
        
        # OK or bust.
        ).done(
            ->
                haibu.sendResponse res, 200, {}
            , (err) ->
                haibu.sendResponse res, 500,
                    'error':
                        'message': err.message
        )