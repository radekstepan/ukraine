#!/usr/bin/env coffee
fs   = require 'fs'
path = require 'path'

haibu = require '../../node_modules/haibu/lib/haibu.js' # direct path to local haibu!

# We request the same file in the main thread.
CFG = JSON.parse fs.readFileSync(path.resolve(__dirname, '../../config.json')).toString('utf8')

# Also define authentication on all requests?
if CFG.auth_token
    haibu.router.every.before = ->
        # Allowed.
        if @req.headers['x-auth-token'] is CFG.auth_token
            if typeof(fn = arguments[arguments.length - 1]) is 'function' then fn()
            else haibu.sendResponse @res, 500, 'message': 'Callback is not a function'
            return true
        
        # Not allowed.
        haibu.sendResponse @res, 403,
            'message': 'Wrong auth token'
        
        false