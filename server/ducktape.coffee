#!/usr/bin/env coffee
path = require 'path'
wrench = require 'wrench'
winston = require 'winston'

# CLI output on the default output.
winston.cli()

# Direct paths to local haibu!
haibu = require '../node_modules/haibu/lib/haibu.js'
spawner = require '../node_modules/haibu/lib/haibu/core/spawner.js'
_trySpawn = spawner.Spawner::trySpawn

tape = exports
tape.name = 'ducktape'
tape.init = (done) -> done()

tape.attach = ->
    # Prefix the default spawner.
    spawner.Spawner::trySpawn = (app, callback) ->
        # Log it.
        winston.warn 'Attempting to cleanup ' + "#{app.user}/#{app.name}".bold + ' if exists'

        # Before attempting any spawn, remove the local repo.
        dir = path.resolve __dirname, "../node_modules/haibu/local/#{app.user}/#{app.name}"
        wrench.rmdirSyncRecursive dir, true

        # Continue as before.
        _trySpawn.apply @, arguments

    # POST environment variables.
    haibu.router.post '/env/:userid/:appid', {} , (userId, appId) ->
        haibu.sendResponse @res, 200,
            'message': 'env set'