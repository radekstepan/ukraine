ukraine
=========

``ukraine`` glues ``haibu`` and ``node-http-proxy`` adding a little helper, ``chernobyl``, that deploys into this cloud. It is probably as stable as you think it is.

Quick start
-----------

Install the package globally:

.. code-block:: bash

    $ sudo npm install ukraine -g

As a server
~~~~~~~~~~~

Start it up:

.. code-block:: bash

    $ sudo ukraine

As a client
~~~~~~~~~~~

Move to a directory with the app to deploy. Deply saying where to:

.. code-block:: bash

    $ chernobyl deploy <ukraine_ip>

Architecture
------------

``ukraine`` spawns a ``node-http-proxy`` server that dynamically watches for changes in a routing table. It also uses a custom loader over ``haibu`` injecting a plugin called ``kgb`` that wiretap listens if a new app has been spawned. If it was, it updates the routing table.