#!/usr/bin/env coffee
fs = require 'fs'
path = require 'path'
wrench = require 'wrench'
winston = require 'winston'

# CLI output on the default output.
winston.cli()

# Direct paths to local haibu!
haibu = require '../node_modules/haibu/lib/haibu.js'
spawner = require '../node_modules/haibu/lib/haibu/core/spawner.js'
_trySpawn = spawner.Spawner::trySpawn
_getSpawnOptions = haibu.getSpawnOptions

tape = exports
tape.name = 'ducktape'
tape.init = (done) -> done()

tape.attach = ->
    # Prefix the default init of repo for spawn.
    spawner.Spawner::trySpawn = (app, cb) ->
        # Log it.
        winston.warn 'Attempting to cleanup ' + "#{app.user}/#{app.name}".bold + ' if exists'

        # Before attempting any spawn, remove the local repo.
        dir = path.resolve __dirname, "../node_modules/haibu/local/#{app.user}/#{app.name}"
        wrench.rmdirSyncRecursive dir, true

        # Continue as before.
        _trySpawn.apply @, arguments

    # Inject our custom env vars after default haibu spawn options
    haibu.getSpawnOptions = (app) ->
        # Get the original opts.
        opts = _getSpawnOptions.apply @, arguments

        # Get custom env file.
        env = JSON.parse fs.readFileSync path.resolve(__dirname, 'env.json')

        # Do we have anything to actually inject?
        if env[app.user] and env[app.user][app.name]
            winston.warn 'Attempting to inject env vars for ' + "#{app.user}/#{app.name}".bold

            # Init env?
            opts.env ?= {}
            # Expand on us.
            ( opts.env[key] = value for key, value of env[app.user][app.name] )

        # Move along.
        opts