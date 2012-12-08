#!/usr/bin/env coffee
fs      = require 'fs'
path    = require 'path'
winston = require 'winston'
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

winston.debug 'Creating new routing and nev table?'

# Do we need to init routing and env tables?
unless fs.existsSync(p = path.resolve(__dirname, "./routes.json")) then fs.writeFileSync p, JSON.stringify {"router":{}}, null, 4
unless fs.existsSync(p = path.resolve(__dirname, "./env.json")) then fs.writeFileSync p, '{}'

winston.debug 'Trying to load config'

# Load config.
try
    cfg = JSON.parse fs.readFileSync(path.resolve(__dirname, '../config.json')).toString('utf-8')
catch e
    return winston.error e.message

winston.debug 'Trying to spawn proxy server'

# Create a proxy server listening on port 80 routing to apps in a dynamic `routes` file.
proxy.createServer('router': path.resolve(__dirname, 'routes.json')).listen(cfg.proxy_port)

winston.debug 'Trying to use custom haibu plugins'

# Inject our own plugins.
for plugin in [ 'ducktape' ]
    haibu.__defineGetter__ plugin, -> require path.resolve(__dirname, "#{plugin}.coffee")
    haibu.use(haibu[plugin], {})

winston.debug 'Trying to start haibu drone'

# Create the hive on port 9002.
haibu.drone.start
    'env': 'development'
    'port': cfg.haibu_port
    'host': '127.0.0.1'
, ->
    # Following will be monkey patching the router with our own functionality.
    winston.debug 'Adding custom routes'

    # Remove all the original routes.
    haibu.router.routes = {}

    for file in wrench.readdirSyncRecursive path.resolve __dirname, './ukraine/'
        require './ukraine/' + file

    # See which apps have been re-spawned from a previous session and update our routes.
    winston.debug 'Updating proxy routing table'
    
    # Traverse running apps.
    table = {}
    ( table["#{cfg.proxy_host}/#{app.name}/"] = "127.0.0.1:#{app.port}" for app in haibu.running.drone.running() )

    # Write the routing table.
    id = fs.openSync path.resolve(__dirname, 'routes.json'), 'w', 0o0666
    fs.writeSync id, JSON.stringify({'router': table}, null, 4), null, 'utf8'

    # We done.
    winston.info 'haibu'.grey + ' listening on port ' + new String(cfg.haibu_port).bold
    winston.info 'http-proxy'.grey + ' listening on port ' + new String(cfg.proxy_port).bold
    winston.info 'cloud apps live in ' + path.resolve(__dirname, '../node_modules/haibu/local').bold