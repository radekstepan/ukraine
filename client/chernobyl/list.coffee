#!/usr/bin/env coffee
fs      = require 'fs'
path    = require 'path'
winston = require 'winston'
tar     = require 'tar'
zlib    = require 'zlib'
fstream = require 'fstream'
request = require 'request'
Q       = require 'q'
require 'colors'

task = exports

# Where is the app we are uploading located?
APP_DIR = '../example_app'

# CLI output on the default output.
winston.cli()

# The actual task.
task.list = (ukraine_ip, cfg) ->
    # Is anyone listening?
    return Q.fcall( ->
        winston.debug 'Is ' + 'haibu'.grey + ' up?'

        def = Q.defer()

        request.get {'url': "http://#{ukraine_ip}:#{cfg.haibu_port}/version"}, (err, res, body) ->
            if err
                def.reject err
            else if res.statusCode isnt 200
                def.reject body
            else
                winston.info (JSON.parse(body)).version.grey + ' accepting connections'
                def.resolve()

        def.promise
    # List apps.
    ).then(
        ->
            winston.debug 'Trying to list running apps'

            def = Q.defer()

            request.get {'url': "http://#{ukraine_ip}:#{cfg.haibu_port}/drones/running"}, (err, res, body) ->
                if err then def.reject err
                else if res.statusCode isnt 200 then def.reject body
                else
                    # All the drones currently running.                    
                    for drone in JSON.parse body
                        winston.data drone.name.bold + '@' + drone.version

                    # All went fine.
                    def.resolve()

            def.promise
    # OK or bust.
    ).done(
        ->
            winston.info 'Apps listed ' + 'ok'.green.bold
        , (err) ->
            winston.error err
    )