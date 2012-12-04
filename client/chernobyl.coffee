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
    winston.help '  chernobyl <action> <ukraine_ip>'
    winston.help ''
    winston.help 'Commands:'.cyan.underline.bold
    winston.help ''
    winston.help 'To deploy an app into cloud'.cyan
    winston.help '  chernobyl deploy'
    winston.help 'To stop an app in the cloud'.cyan
    winston.help '  chernobyl stop'
    winston.help 'To list apps in the cloud'.cyan
    winston.help '  chernobyl list'
    winston.help ''

# Do we have config available?
try
    cfg = JSON.parse fs.readFileSync(path.resolve(__dirname, '../config.json')).toString('utf-8')
catch e
    return winston.error e.message

# Which command?
if process.argv.length < 3 then help()
else
    switch task = process.argv[2]
        when 'deploy', 'stop', 'list'
            # Has the user supplied a path to ukraine?
            if process.argv.length isnt 4
                winston.error "Path to #{'ukraine'.grey} not specified"
                help()
            else
                winston.info "Executing the #{task.magenta} command"
                (require path.resolve(__dirname, "chernobyl/#{task}.coffee"))[task](process.argv[3], cfg)
        else
            help()