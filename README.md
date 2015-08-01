# Blockbridge Volume Plugin for Docker

The Blockbridge volume plugin for Docker provides access to an extensible set
of container-based persistent storage options for single and multi-host Docker
environments with features that include tenant isolation, automated
provisioning, encryption, secure deletion, snapshots and QoS.

This volume plugin requires Blockbridge Elastic Programmable Storage as the
storage backend. To use a Blockbridge storage simulator, or for more
information about Blockbridge see below.

## Installation

The Blockbridge volume plugin runs as a Docker container right alongside your
application containers.

Checkout the git repository:
````
git clone https://github.com/blockbridge/blockbridge-docker-volume.git
cd blockbridge-docker-volume
````

## Driver Configuration

The volume driver needs to be configured with an API backend host, and a `system` API token.

If using the Blockbridge simulator container, retrieve the IP address and API
key from the management node:

````
# docker logs bbsim-mn
IP Address:      172.17.42.121
Admin API Key:   1/4pz/TrwO0l53xY8j6VkorTZu2wJEeaaH5PktWI2AxSXynP9OvA7THw
````

Then, set these values as an environment variable, or edit the
`bin/blockbridge-docker-volume` script and set them there.

````
export BLOCKBRIDGE_API_HOST="172.17.42.121"
export BLOCKBRIDGE_API_KEY="1/4pz/TrwO0l53xY8j6VkorTZu2wJEeaaH5PktWI2AxSXynP9OvA7THw"
````

## Start the volume driver

Once configured, start the driver:

````
bin/blockbridge-docker-volume
````

## Volume Configuration

Each volume can specify unique attributes, capacity, a user, and a type of
volume in an environment files. By default, these files are located in
`/bb/env` and the name of the file must match the name of the volume being
created.

Each volume environment file has at least the following settings:

    TYPE, USER, CAPACITY, ATTRIBUTES

* `TYPE`: the type of storage container for the volume. This can currently either
by `autovol` or `snappy`.
* `USER`: a blockbridge username/account to provision the volume for
* `CAPACITY`: the capacity of the volume. This can be specified with units, such as
32GiB.
* `ATTRIBUTES`: storage attributes for the volume. These user defined attributes
are set on the blockbridge datastore, and determines the what kind of storage,
or what location to provision from. This can include tags such as "+ssd,
"+us-east-1c" to include, or "-production" to exclude. This field can be left
blank, and the default provisioning algorithm is used.

For example, let's create an env file for a volume for a busybox container

`/bb/env/busybox-demo`:
````
TYPE=autovol
USER=busybox
CAPACITY=32GiB
ATTRIBUTES=+ssd
````

## Start a container with a Blockbridge volume

Start the busybox container wth a data volume that was just configured:

````
docker run --rm -ti busybox-demo:/data --volume-driver=blockbridge busybox sh
````

And the volume is mounted on /data in the container:
````
# df /data
Filesystem           1K-blocks      Used Available Use% Mounted on
/dev/blockbridge/volume-busybox-demo/sdc
                      33537988     33312  33504676   0% /data
````

## Blockbridge Storage

The Blockbridge volume plugin uses Blockbridge Elastic Programmable Storage as
the backend. For more information on Blockbridge, please visit
[http://blockbridge.io/docker](http://blockbridge.io/docker).

## Blockbridge Storage Simulator

Blockbridge storage is available as a simulator for trial and non-production
use. The simulator also runs as a Docker container.

See
* [blockbridge-demo](https://github.com/blockbridge/blockbridge-demo)
* [blockbridge-demo/simulator/README.md](https://github.com/blockbridge/blockbridge-demo/blob/master/simulator/README.md)

for information on how to run a simulator for your platform.

## Support

Please let us know what you think! Contact us at support@blockbridge.com.
