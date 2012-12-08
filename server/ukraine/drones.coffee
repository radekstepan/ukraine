#!/usr/bin/env coffee
winston = require 'winston'
Q       = require 'q'

haibu = require '../../node_modules/haibu/lib/haibu.js' # direct path to local haibu!

# GET list all them running drones.
haibu.router.get '/drones', {} , ->
    req = @req ; res = @res
    
    # Listing running apps drones.
    return Q.fcall( ->
        winston.debug 'Listing running apps drones'

        haibu.running.drone.running()
    # OK or bust.
    ).done(
        (running) ->
            haibu.sendResponse res, 200, running
        , (err) ->
            haibu.sendResponse res, 500,
                'error':
                    'message': err.message
    )

# GET one of them running drones.
haibu.router.get '/drones/:name', {} , (APP_NAME) ->
    req = @req ; res = @res
    
    # Good headers?
    return Q.fcall( ->
        winston.debug 'Get running app drone'

        # Use this if you know what you are doing, exposes whole of env...
        # if s = haibu.running.drone.show(APP_NAME) then return s else throw 'App not found'

        # Only expose us from a simple running list.
        for app in haibu.running.drone.running()
            if app.name is APP_NAME then return app
        throw 'App not found'
    # OK or bust.
    ).done(
        (running) ->
            haibu.sendResponse res, 200, running
        , (err) ->
            haibu.sendResponse res, 404,
                'error':
                    'message': err.message or err
    )