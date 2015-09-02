# Blockbridge Volume Plugin for Docker

Version 2.0

The Blockbridge volume plugin for Docker provides access to an extensible set
of container-based persistent storage options. It supports single and multi-host Docker
environments with features that include tenant isolation, automated
provisioning, encryption, secure deletion, snapshots and QoS.

This volume plugin requires Blockbridge Elastic Programmable Storage as the
storage backend. To use a Blockbridge storage simulator, or for more
information about Blockbridge, see below.

Docker 1.8+ is required to use the volume plugin.

## Demo

[![A closer look at docker volume plugins in action](https://cloud.githubusercontent.com/assets/5973862/9637035/84d5f6e6-516c-11e5-9656-46dcae410569.png)](http://www.blockbridge.com/a-closer-look-at-docker-volume-plugins-in-action/)

## Installation

The Blockbridge volume plugin runs as a Docker container right alongside your
application containers.

Checkout the git repository:
````
git clone https://github.com/blockbridge/blockbridge-docker-volume.git
cd blockbridge-docker-volume
````

The volume driver is available to run directly from the Docker hub registry. The script to run the driver is included here.

## Driver Configuration

The volume driver needs to be configured with a Blockbridge API backend host, and a `system` API token.

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

The Blockbridge volume driver should now be running:
````
# docker ps
CONTAINER ID        IMAGE                       COMMAND                CREATED              STATUS              PORTS                                      NAMES
f9bba845cc12        blockbridge/volume-driver   "./volume-driver"      About a minute ago   Up About a minute                                              blockbridge-volume-driver
````

## Volume Configuration

In order to use a Blockbridge volume in a container it must be configured via an environment configuration file. By default, these files are located in`/bb/env` and the name of the file must match the name of the volume being used. Each volume configuration file specifies the type of volume, capacity, user/account to provision for, and unique volume attributes. 

This configuration is specified in the file with the following settings:

    TYPE, USER, CAPACITY, ATTRIBUTES

* `TYPE`: the type of Blockbridge storage container for this volume. This can currently either
be `autovol` or `snappy`. See below for description of the Blockbridge Storage as a Container types.
* `USER`: a Blockbridge username/account to provision the volume for.
* `CAPACITY`: the capacity of the volume. This can be specified with units, such as
32GiB.
* `ATTRIBUTES`: storage attributes for the volume. These user defined attributes
are set on the blockbridge datastore, and determines what kind of storage to provision, what location to provision from, rack, datacenter, etc. This can include tags such as "+ssd,
"+us-east-1c" to include, or "-production" to exclude. This field can be left
blank, and the default provisioning algorithm is used.

For example, let's create a configuration file for a volume for a busybox container.

`/bb/env/busybox-demo`:
````
TYPE=autovol
USER=block
CAPACITY=32GiB
````

If configured on the backend, specify provisioning attributes as desired:

````
ATTRIBUTES=+ssd +us-east-1c -production
````

## Start a container with a Blockbridge volume

Start the busybox container with the data volume that was just configured:

````
docker run --rm -ti --volume busybox-demo:/data --volume-driver=blockbridge busybox sh
````

The volume name `busybox-demo` is the unique volume name. This name must match the configuration file name in `/bb/env`, and is considered a unique volume to Docker.

NOTE: the very first volume you use with the volume driver set to `blockbridge` may take slightly longer to load. This is due to images that don't yet exist locally being pulled down from Docker.

After `busybox` loads, the volume is mounted on `/data` in the container:
````
# df /data
Filesystem           1K-blocks      Used Available Use% Mounted on
/dev/blockbridge/volume-busybox-demo/sdc
                      33537988     33312  33504676   0% /data
````

You are now using Blockbridge persistent, multi-tenant, secure storage for your Docker volumes!

## Blockbridge Storage

The Blockbridge volume plugin for Docker uses Blockbridge Elastic Programmable Storage as
the backend.

Please visit for more information:

* [http://blockbridge.io/docker](http://blockbridge.io/docker)
* [http://blockbridge.io](http://blockbridge.io)

## Blockbridge Storage Simulator

Blockbridge storage is available as a simulator for trial and non-production
use. The simulator also runs as a Docker container. This is an easy way to try out Blockbridge storage, and to try out the Blockbridge volume plugin for Docker.

Please visit for more information:

* [blockbridge-demo](https://github.com/blockbridge/blockbridge-demo)
* [blockbridge-demo/simulator/README.md](https://github.com/blockbridge/blockbridge-demo/blob/master/simulator/README.md)

## Blockbridge Storage as a Container volume types

### autovol

The `autovol` storage container type is the basic Blockbridge storage container option, and provisons an "automatic volume". To use `autovol`, specify the TYPE in the volume env file:

````
TYPE=autovol
```

### snappy

The `snappy` storage container type extends the `autovol` container by providing snapshot support. Periodic snapshots are taken of the volume, as configured. These snapshots are done with zero I/O.

To use a `snappy` volume, specify the following options in the volume env file:

```
TYPE=snappy
SNAPSHOT_INTERVAL_HOURS=1
SNAPSHOT_INTERVAL_HISTORY=24
```

This configuration will take a snapshot once an hour, and retain the last 24 hours of snapshot history for the volume.

## OPTIONAL: build the Blockbridge volume driver

The Blockbridge volume driver is available on the Docker hub registry. If desired, it can also be built locally.

Simply type:

````
make
````

And an updated image will be built and available. The script `bin/blockbridge-docker-volume` when run will stop and remove any currently running driver, so can be run again to start the volume driver with the new image.

````
bin/blockbridge-docker-volume
```

## OPTIONAL: iscsid

The Blockbridge volume driver uses and requires iSCSI by running `iscsid`, and will conflict with the system iscsid if it is not disabled first. Either first disable any iscsid service on the client host, or the following script can be run to disable it for you:

* [blockbridge-demo/iscsid/disable-host-iscsid.sh](https://github.com/blockbridge/blockbridge-demo/blob/master/iscsid/disable-host-iscsid.sh)

## Support

Please let us know what you think! Contact us at support@blockbridge.com.
