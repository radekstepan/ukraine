#!/usr/bin/env coffee
fs      = require 'fs'
path    = require 'path'
winston = require 'winston'
require 'colors'

# CLI output on the default output.
winston.cli()

# Show help.
help = ->
    winston.help ''
    ( winston.help line.cyan.bold for line in fs.readFileSync('logo.txt').toString('utf-8').split('\n') )
    winston.help ''
    winston.help 'Deployment of Node.js cloud apps'
    winston.help ''
    winston.help 'Commands:'.cyan.underline.bold
    winston.help ''
    winston.help 'To deploy an app into cloud'.cyan
    winston.help '  chernobyl deploy <ukraine_ip>'

winston.info "Welcome to #{'chernobyl'.grey} comrade"

# Which command?
if process.argv.length < 3 then help()
else
    switch process.argv[2]
        when 'deploy'
            # Has the user supplied a path to ukraine?
            if process.argv.length isnt 4
                winston.error "Path to #{'ukraine'.grey} not specified"
                help()
            else
                (require path.resolve(__dirname, 'chernobyl/deploy.coffee')).deploy process.argv[3]
        else
            help()