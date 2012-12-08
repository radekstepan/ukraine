#!/usr/bin/env coffee
fs      = require 'fs'
path    = require 'path'
winston = require 'winston'

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
    winston.debug 'Adding custom routes'

    require './ukraine/env.coffee'

    # We done.
    winston.info 'haibu'.grey + ' listening on port ' + new String(cfg.haibu_port).bold
    winston.info 'http-proxy'.grey + ' listening on port ' + new String(cfg.proxy_port).bold
    winston.info 'cloud apps live in ' + path.resolve(__dirname, '../node_modules/haibu/local').bold