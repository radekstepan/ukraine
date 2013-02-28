#!/usr/bin/env coffee
fs      = require 'fs'
winston = require 'winston'
urlib   = require 'url'

{ cfg } = require '../ukraine.coffee'

winston.cli()

# Do we have the config?
throw 'Config file not present' unless cfg

class Router

    # Are we using non standard port? Else leave it out.
    port: (if (cfg.proxy_port isnt 80) then ":#{cfg.proxy_port}" else '')

    # `proxy_hostname_only` property.
    hostnameOnly: cfg.proxy_hostname_only or false

    # Init the file in path.
    constructor: (@path) ->
        try
            @routes = require @path
        catch e
            @routes = { } # go blank, mishandled file etc.

        # Keep watching the file for changes.
        fs.watchFile @path, =>
            winston.warn 'Router edited'
            fs.readFile @path, 'utf8', (err, data) =>
                unless err
                    try
                        # No checking, if is JSON, is valid...
                        @routes = JSON.parse data
                    catch e
                        # silence!

    # Route handler.
    route: (req, res, proxy) =>
        # 'Hostname Only' routing.
        if @hostnameOnly
            # Traverse all our apps and find an app to match.
            for path, target of @routes
                # Does the subdomain match?
                if req.headers.host.match new RegExp('^' + path, 'i')
                    # Proxy.
                    return proxy.proxyRequest req, res, { 'host': target.host, 'port': target.port }

                # Maybe we have a custom domain specified?
                continue unless target.domains and target.domains instanceof Array
                for domain in target.domains
                    if req.headers.host.match new RegExp('^' + domain, 'i')
                        # Proxy.
                        return proxy.proxyRequest req, res, { 'host': target.host, 'port': target.port }
        
        # 'Folder' based routing.
        else
            # Traverse all our apps and find an app to match.
            for path, target of @routes
                # Does the 'folder' match?
                if req.url.match new RegExp("^\/#{path}", 'i')

                    # Replace the path by stripping the folder.
                    parsed = urlib.parse req.url
                    parsed.pathname = parsed.pathname.replace '/' + path, ''
                    req.url = urlib.format parsed

                    # Proxy.
                    return proxy.proxyRequest req, res, { 'host': target.host, 'port': target.port }


        # Sadness...
        winston.error 'No route to ' + req.url.bold
        res.writeHead 404
        res.end 'No app deployed here'

    update: (app_name, app_port) ->
        # Removing this app?
        unless app_port
            delete @routes[app_name]

        # Updating its port then.
        else
            # Init?
            app = @routes[app_name] ?= { 'host': '127.0.0.1' }
            # Change the port for this app.
            app.port = app_port

    # Write the routing table into a file.
    write: (cb) ->
        fs.writeFile @path, @serialize(), 'utf8', (err) ->
            if err then cb err.message
            else cb null

    # Serialize router into a nice string.
    serialize: -> JSON.stringify @routes, null, 4

module.exports = Router