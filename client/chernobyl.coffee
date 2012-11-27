#!/usr/bin/env coffee 
fs = require 'fs'
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

# Startup.
winston.info "Welcome to #{'chernobyl'.grey} comrade"
try
    pkg = JSON.parse fs.readFileSync './package.json'
catch e
    winston.error "#{'package.json'.grey} file does not exist"

if pkg
    winston.info 'v' + pkg.version
    winston.info 'Executing command'

    if process.argv.length < 3 then help()
    else
        switch process.argv[2]
            when 'deploy'
                winston.debug '    debugging'
            else
                help()