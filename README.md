# Blockbridge Volume Plugin for Docker

Version 3.0

The Blockbridge volume driver integrates Docker with Blockbridge storage
services in single and multi-host Docker deployments. Using Blockbridge enables
tenant isolation, automated provisioning, encryption, secure deletion,
snapshots and QoS for any storage backend: on local storage or with any storage
vendor over any protocol.

The Blockbridge volume driver implements the Docker volume plugin API, and runs
as a container.

The Blockbridge storage backend is available as a simulator running as a Docker
container, and is free for development and non-commercial use. Use the storage
simulator alongside the volume driver on the same host for a simple test, or
use multiple hosts and aggregate storage pools across multiple storage nodes.

The volume driver and storage simulator are supported on any Linux platform
that runs Docker, including CoreOS and OSX (boot2docker/docker-machine).

- Docker 1.8+: required to use the volume plugin.
- Docker 1.9:  adds volume management and volume options (e.g.: docker volume create --driver blockbridge --opt ...).
- Docker 1.10: adds support for out-of-band, multi-host volume management.

Table of Contents
=================

  * [Blockbridge Volume Plugin for
    Docker](#blockbridge-volume-plugin-for-docker)
    * [Installation](#installation)
    * [Driver Configuration](#driver-configuration)
    * [Start the volume driver](#start-the-volume-driver)
    * [Volume Types](#volume-types)
      * [Autovol](#autovol)
      * [Autoclone](#autoclone)
      * [Snappy](#snappy)
    * [Volume Options](#volume-options)
      * [User](#user)
      * [Capacity](#capacity)
      * [IOPS](#iops)
      * [Clone Basis (autoclone)](#clone-basis-autoclone)
      * [Snapshot Tag (autoclone)](#snapshot-tag-autoclone)
      * [Snapshot Interval Hours (snappy)](#snapshot-interval-hours-snappy)
      * [Snapshot Interval History (snappy)](#snapshot-interval-history-snappy)
    * [Attribute based provisioning](#attribute-based-provisioning)
    * [Create a volume in Docker (in-band)](#create-a-volume-in-docker-in-band)
      * [Docker volume create (Explicit)](#docker-volume-create-explicit)
      * [Docker volume create (Implicit)](#docker-volume-create-implicit)
      * [Docker run with volume](#docker-run-with-volume)
      * [List volumes with docker](#list-volumes-with-docker)
      * [Inspect volume with docker](#inspect-volume-with-docker)
    * [Create a volume with Blockbridge (out-of-band: docker 1.10
      )](#create-a-volume-with-blockbridge-out-of-band-docker-110)
      * [Create a volume (out-of-band):](#create-a-volume-out-of-band)
      * [List volumes (out-of-band)](#list-volumes-out-of-band)
      * [Inspect volumes (out-of-band)](#inspect-volumes-out-of-band)
      * [Inspect one volume (out-of-band)](#inspect-one-volume-out-of-band)
      * [Full command help (out-of-band)](#full-command-help-out-of-band)
    * [Volume Profiles](#volume-profiles)
      * [Volume Profiles Provisioning
        Attributes](#volume-profiles-provisioning-attributes)
        * [(Example) Gold Storage Profile](#example-gold-storage-profile)
        * [(Example) Availability Zone East
          Profile](#example-availability-zone-east-profile)
        * [(Example) Rack42 Profile](#example-rack42-profile)
      * [List Profiles](#list-profiles)
      * [Inspect one Profile](#inspect-one-profile)
      * [Full command help](#full-command-help)
    * [Anonymous / Default Volumes](#anonymous--default-volumes)
    * [Multi-Host Volumes](#multi-host-volumes)
      * [Create a profile on host #1](#create-a-profile-on-host-1)
      * [Use a volume on host #2](#use-a-volume-on-host-2)
      * [Use the volume on host #3 with
        zero-copy](#use-the-volume-on-host-3-with-zero-copy)
    * [Blockbridge Storage](#blockbridge-storage)
    * [Blockbridge Storage Simulator](#blockbridge-storage-simulator)
    * [Support](#support)

## Installation

Pull the volume driver image:
````
docker pull blockbridge/volume-driver:latest
````

Clone this repository to run the volume driver startup script:
````
git clone https://github.com/blockbridge/blockbridge-docker-volume.git
cd blockbridge-docker-volume
````

## Driver Configuration

The volume driver requires two pieces of configuration. It needs to know the
Blockbridge management node that is providing storage services. And it
needs an API authorization token to use for authentication.

The Blockbridge storage simulator automatically generates this information when
it runs for the first time. Retrieve the IP address and API authorization from
the simulator management node.

````
# docker logs bbsim-mn
IP Address:      172.17.42.121
Admin API Key:   1/4pz/TrwO0l53xY8j6VkorTZu2wJEeaaH5PktWI2AxSXynP9OvA7THw
````

Configure the volume driver by setting two environment variables.

````
export BLOCKBRIDGE_API_HOST="172.17.42.121"
export BLOCKBRIDGE_API_KEY="1/4pz/TrwO0l53xY8j6VkorTZu2wJEeaaH5PktWI2AxSXynP9OvA7THw"
````

## Start the volume driver

````
./bin/blockbridge-docker-volume
````

Alternatively, set the environment and start the driver at the same time:

````
BLOCKBRIDGE_API_HOST="172.17.42.121" BLOCKBRIDGE_API_KEY="1/4pz/TrwO0l53xY8j6VkorTZu2wJEeaaH5PktWI2AxSXynP9OvA7THw" ./bin/blockbridge-docker-volume
````

Confirm the driver is running:
````
# docker ps
CONTAINER ID        IMAGE                       COMMAND                CREATED              STATUS              PORTS                                      NAMES
f9bba845cc12        blockbridge/volume-driver   "./volume-driver.sh"      About a minute ago   Up About a minute                                              blockbridge-volume-driver
````

## Volume Types

The Blockbridge volume driver supports multiple volume types which determine
the behavior of the volumes. All volume types are provisioned according to the
volume options and provisioning attributes specified.

### Autovol

The basic and default type.

### Autoclone

An **autoclone** volume first clones a virtual disk snapshot identified as the
basis. Any modifications occur in the clone, keeping the original data intact.

### Snappy

An evolution from **autovol**, a **snappy** volume periodically takes snapshots of
the volume data. Snaphot interval and retention history is configurable, and your
filesystem is always consistent.

## Volume Options

The volume is provisioned according to the options specified. The volume type
determines the required options. As Blockbridge is multi-tenant storage, a
**User** is always required.

### User

The user (tenant) to provision the volume for.

Option name: **user**

### Capacity

The volume capacity.

Option name: **capacity**

### IOPS

The volume quality of service (QoS). This is a reserved, guaranteed minimum
IOPS performance of the volume. It requires QoS configuration on the backend.

Option name: **iops**

### Clone Basis (autoclone)

The basis disk to clone the snapshot from.

Option name: **clone_basis**

### Snapshot Tag (autoclone)

The tag that identifies the snapshot to clone.

Option name: **snapshot_tag**

### Snapshot Interval Hours (snappy)

The interval at which to take a snapshot (every N hours)

Option name: **snapshot_interval_hours**

### Snapshot Interval History (snappy)

The number of snapshots to retain.

Option name: **snapshot_interval_history**

## Attribute based provisioning

In addition to the required volume options, volume provisioning attributes can
be specified to determine particular qualities of the storage to provision
from.

These attributes are configured by an administrator on the Blockbridge storage
backend, and then specified by the volume driver as query parameters.

Attributes such as SSD, IOPS 30000, Rack 42, New York, Chicago, Production, all
identify unique sets of storage pools.

Specifying provisioning attributes provides an automated and fundamental way to
describe the exact storage characteristics you want to provision for your
volume.

## Create a volume in Docker (in-band)

There are two ways in Docker to create a volume, either explicitly via *docker
volume create* or implicitly at *docker run* time.

### Docker volume create (Explicit)

Create a blockbridge volume:
````
docker volume create --driver blockbridge --name datavol --opt user=block --opt capacity=32GiB
````

### Docker volume create (Implicit)

Once a default profile has been configured (see below), create a blockbridge volume:
````
docker run --volume-driver blockbridge -v datavol:/data -it busybox sh
````

NOTE: you cannot pass volume options on the commandline during *docker run*,
these can only be specified explicitly with *docker volume create --opt*, or a
Blockbridge default volume profile must be setup.

### Docker run with volume

Reference existing Blockbridge volume at docker run:
````
docker run -v datavol:/data -it busybox sh
````

### List volumes with docker
````
docker volume ls
````

### Inspect volume with docker
````
docker volume inspect datavol
````

## Create a volume with Blockbridge (out-of-band: docker 1.10+)

The Blockbridge volume driver supports out of band volume creation, outside of
Docker. In Docker 1.10, the volume driver is responsible for maintaining a list
of volumes, and Docker does not keep its own state about third-party volumes
available through plugins.

### Create a volume (out-of-band):
````
docker exec blockbridge-volume-driver volume create --name datavol --user block --capacity 32GiB
````

### List volumes (out-of-band)
````
docker exec blockbridge-volume-driver volume ls
````

### Inspect volumes (out-of-band)
````
docker exec blockbridge-volume-driver volume info
````

### Inspect one volume (out-of-band)
````
docker exec blockbridge-volume-driver volume info --name datavol
````

### Full command help (out-of-band)
````
docker exec blockbridge-volume-driver volume --help
````

## Volume Profiles

Blockbridge volume profiles are a way to describe different sets of volume
options and provisioning attributes as a **Storage Profile** or **Storage
Template**.  Instead of specifying each individual option every time a volume is
created, a volume profile can be referenced.

Create a profile with the volume driver:
````
docker exec blockbridge-volume-driver profile create --name block-profile --user block --capacity 32GiB
````

Reference the profile to create a volume. Each volume that uses this
**block-profile** will be created for the **block** user with a capacity of
**32GiB**.
````
docker volume create --driver blockbridge --name datavol2 --opt profile=block-profile
````

### Volume Profiles Provisioning Attributes

The power of volume profiles comes from defining sets of options and defining
storage provisioning attributes. For example, you may have different classes of
storage, Gold and Silver. You may have storage in different availability zones,
different racks in a datacenter, different storage media (ssd, spinners), and
for different users.

Define profiles that make sense for your environment.

#### (Example) Gold Storage Profile
````
docker exec blockbridge-volume-driver profile create --name gold --user block --capacity 1TiB +ssd +production +multipath +high-iops
````

#### (Example) Availability Zone East Profile
````
docker exec blockbridge-volume-driver profile create --name us-east --user block --capacity 10GiB +us-east +ssd -production
````

#### (Example) Rack42 Profile
````
docker exec blockbridge-volume-driver profile create --name rack42 --user block --capacity 16GiB +rack42
````

### List Profiles
````
docker exec blockbridge-volume-driver profile ls
````

### Inspect one Profile
````
docker exec blockbridge-volume-driver profile info --name rack42
````

### Full command help
````
docker exec blockbridge-volume-driver profile --help
````

## Anonymous / Default Volumes

Many volumes in Docker are so-called **anonymous** volumes, or unnamed volumes.
These volumes get a generated name that looks like a long hash string. The
Blockbridge volume driver supports these volumes through the specification of a
**default** volume profile. Any volume that gets created through the Blockbridge
volume driver with no options or profile specified will use the **default**
volume profile if it is defined.

The default volume profile is a specially named profile, appropriately named as
**default**.

Create the default profile:
````
docker exec blockbridge-volume-driver profile create --name default --user block --capacity 32GiB
````

Use the default profile by using an anonymous volume:
````
docker run --volume-driver blockbridge -v /data -it busybox sh
````

Use the default profile by using a named volume with no options:
````
docker volume create --driver blockbridge --name defaultvol
````

## Multi-Host Volumes

All volumes created through Blockbridge are by definition multi-host volumes.
The same goes for volume **Storage Profiles**. Create a volume or a profile
through one Blockbridge volume driver, and that volume or profile is accessible
from any other host, through any other Blockbridge volume driver.

Volumes are globally accessible. Volume profiles are global.

### Create a profile on host #1
````
host1$ docker exec blockbridge-volume-driver profile create --name default --user block --capacity 32GiB
````

### Use a volume on host #2
````
host2$ docker run --name mongo-app --volume-driver blockbridge -v mongodata:/data/db -d mongo
````

[ *Write data to volume..* ]

````
host2$ docker stop mongo-app
````

### Use the volume on host #3 with zero-copy
````
host3$ docker run --name mongo-app --volume-driver blockbridge -v mongodata:/data/db -d mongo
````

Blockbridge volumes are accessible on any host, with no data copy required.

## Blockbridge Storage

The Blockbridge volume driver for Docker uses Blockbridge storage services as
the backend.

* [http://blockbridge.io/docker](http://blockbridge.io/docker)
* [http://blockbridge.io](http://blockbridge.io)

## Blockbridge Storage Simulator

The Blockbridge storage backend is available as a simulator running as a Docker
container, and is free for development and non-commercial use.

* [blockbridge-demo](https://github.com/blockbridge/blockbridge-demo)
* [blockbridge-demo/simulator/README.md](https://github.com/blockbridge/blockbridge-demo/blob/master/simulator/README.md)

## Support

Please let us know what you think! Contact us at support@blockbridge.com or on
github.
