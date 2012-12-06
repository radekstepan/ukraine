#!/usr/bin/env coffee
fs      = require 'fs'
path    = require 'path'
winston = require 'winston'
require 'colors'

# CLI output on the default output.
winston.cli()

winston.info "Welcome to #{'chernobyl'.grey} comrade"

# Show welcome logo and desc.
( winston.help line.cyan.bold for line in fs.readFileSync(path.resolve(__dirname, 'logo.txt')).toString('utf-8').split('\n') )
winston.help ''
winston.help 'Deployment of Node.js cloud apps'
winston.help ''

# Show help.
help = ->
    winston.help 'Usage:'.cyan.underline.bold
    winston.help ''
    winston.help '  chernobyl <action> <ukraine_ip> <app_path>'
    winston.help ''
    winston.help 'Commands:'.cyan.underline.bold
    winston.help ''
    winston.help 'To deploy an app into cloud'.cyan
    winston.help '  chernobyl deploy'
    winston.help 'To stop an app in the cloud'.cyan
    winston.help '  chernobyl stop'
    winston.help 'To list apps in the cloud'.cyan
    winston.help '  chernobyl list'
    winston.help 'To send an environment variable'.cyan
    winston.help '  chernobyl env ... <key>="<value>"'
    winston.help ''

# Do we have config available?
try
    cfg = JSON.parse fs.readFileSync(path.resolve(__dirname, '../config.json')).toString('utf-8')
catch e
    return winston.error e.message

if process.argv.length < 3 then help()
else
    # Expand the args.
    [ _1, _2, task, ukraine_ip, app_path, _3 ] = process.argv

    # Default app path.
    app_path = app_path or '.'

    # Which task?    
    switch task
        when 'deploy', 'stop', 'list', 'env'
            # Has the user supplied a path to ukraine?
            unless ukraine_ip
                winston.error "Path to #{'ukraine'.grey} not specified"
                help()
            else
                if task is 'env'
                    unless _3
                        winston.error "No key=value pair specified"
                        help()
                    else
                        winston.info "Executing the #{task.magenta} command"
                        (require path.resolve(__dirname, "chernobyl/#{task}.coffee"))[task](ukraine_ip, app_path, _3, cfg)
                else
                    winston.info "Executing the #{task.magenta} command"
                    (require path.resolve(__dirname, "chernobyl/#{task}.coffee"))[task](ukraine_ip, app_path, cfg)
        else
            help()