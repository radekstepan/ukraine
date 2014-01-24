ukraine
=========

Open Source Node.js PaaS with automatic proxy and cli client.

``ukraine`` glues ``haibu`` and ``node-http-proxy`` adding a little helper, ``chernobyl``, that deploys into this cloud. It is probably as stable as you think it is.

.. image:: https://raw.github.com/radekstepan/ukraine/master/example.png

Quick start
-----------

Make sure you have ``node >= 0.8.0`` `installed <https://github.com/joyent/node/blob/master/README.md#to-build>`_.

Install the package globally:

.. code-block:: bash

    $ sudo npm install ukraine -g

Create a ``config.json`` file if not present already in the lib's root:

.. code-block:: json

    {
        "haibu_port": 9002,
        "proxy_port": 80,
        "proxy_host": "127.0.0.1",
        "auth_token": "abc",
        "proxy_hostname_only": false
    }

haibu_port
    On which port to start the Haibu service.
proxy_port
    Where will all requests go? If set to ``80``, you will be able to access your apps without providing a port number.
proxy_host
    What is the host used in the proxy routing table. This is the 'domain' you will be using to access the running apps.
auth_token
    A token that a client will need to use to access the ukraine service. Leaving this property out will not require you to pass a token and is useful for debugging.
proxy_hostname_only
    If set to ``true`` your apps will be routed from ``<app_name>.<proxy_host>:<proxy_port>`` instead of ``<proxy_host>:<proxy_port>/<app_name>/``. Useful also in a case when you have links in your app that are root relative.

As a server
~~~~~~~~~~~

Start it up:

.. code-block:: bash

    $ sudo ukraine

.. note::
    In order to run the server in the background, I recommend you install `forever.js <https://github.com/nodejitsu/forever>`_ and start the service as follows:

    .. code-block:: bash

        $ sudo npm install forever -g
        $ sudo forever start /usr/local/lib/node_modules/ukraine/bin/ukraine

As a client
~~~~~~~~~~~

Move to a directory with the app to deploy. Deploy pointing to cloud instance:

.. code-block:: bash

    $ chernobyl deploy <ukraine_ip> <path_to_app>

Config
-----------

For setting environment variables exposed through ``process.env``, set the key value pair ``env`` in your app's ``package.json`` file. You can also use the ``chernobyl`` app itself to pass them if you do not want to expose them in a public ``package.json`` file.

Custom domains
~~~~~~~~~~~~~~

When the ``proxy_hostname_only`` is set to ``true``, one can define custom domains that the app will respond to by editing the ``server/routes.json`` file adding a ``domains`` list under the app's entry. Example:

.. code-block:: javascript

    {
        "example-app": {
            "domains": [
                "helios-one.newvegas"
            ],
            "host": "127.0.0.1",
            "port": 51380
        }
    }

This means that if we do not match on an app's name domain which is ``/^example-app.newvegas/i``, we will attempt to match on ``/^helios-one.newvegas/i``.

Changes to this file do not require the restarting of the ``ukraine`` instance. The proxy will route on the first match and goes through the domains in a top to bottom fashion. The order of apps is determined by whatever ``for (key in obj) {}`` returns.

Architecture
------------

ukraine
    Spawns a ``node-http-proxy`` server that dynamically watches for changes in a routing table. All (useful) routes to ``haibu`` have been overwritten using promises.
    
    New method for posting env vars has been added.

    Token authentication per ukraine instance has been added too.

chernobyl
    #. checks that your app's `package.json` file is in order
    #. checks that ``ukraine`` instance is up
    #. check if we need to auth to deploy an app
    #. checks and stops an existing app if need be
    #. packs the new app and sends it to the cloud to deploy

Troubleshooting
---------------

Be aware of these facts re ukraine/haibu:

#. If you intend to use the API haibu exposes, be sure to send correct parameters in the right format, otherwise you will shut down the app.
#. Your ``package.json`` start script can only include a file name, not a bash command! Haibu checks that whatever you put in there is an existing file. Even more annoyingly, the file needs to be a js file that node can call.
#. Sometimes zlib complains when streaming a package, the code here attempts to keep packing and streaming apps to deploy if it gets these errors.
#. Uploading a new version of the app would not necessarily invalidate the old version, thus we brutforce remove the previous apps.
#. When an app is deployed, it might still take a second or two for it to actually show over the proxy server.
#. Although it should be allowed, haibu only allows to kill an app by its name, not name and username so we all deploy apps into a ``chernobyl`` namespace and if you want to deploy the same app again on a different port, you need to change its ``name`` in ``config.json``.
#. Restarting the app does not work as one would expect getting the latest env variables, stopping does not either expecting an ``application`` object instead of the ``name`` it is passed from the service. When setting new environment variable, then, we take a custom approach of stopping a running instance, getting the latest hash of its package and starting it again with these settings.

That is why we use our own version of it since `v0.12.0`


.. image:: https://d2weczhvl823v0.cloudfront.net/radekstepan/ukraine/trend.png
   :alt: Bitdeli badge
   :target: https://bitdeli.com/free

