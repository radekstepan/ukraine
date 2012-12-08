#!/usr/bin/env coffee
winston = require 'winston'
Q       = require 'q'

haibu = require '../../node_modules/haibu/lib/haibu.js' # direct path to local haibu!

# GET haibu version (check it is running).
haibu.router.get '/version', {} , ->
    res = @res

    # Get haibu version.
    return Q.fcall( ->
        winston.debug 'Getting haibu version'
        haibu.version
    # OK or bust.
    ).done(
        (version) ->
            haibu.sendResponse res, 200,
                'version': "haibu #{version}"
        , (err) ->
            haibu.sendResponse res, 500,
                'error':
                    'message': err.message or err
    )