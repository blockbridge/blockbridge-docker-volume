# Blockbridge Volume Plugin for Docker

Version 4.0

The Blockbridge volume driver integrates Docker with Blockbridge elastic block
storage. Blockbridge enables tenant isolation, automated provisioning,
encryption, secure deletion, snapshots and QoS for any storage backend: on
local storage or with any storage vendor over any protocol.

The Blockbridge volume driver implements the Docker volume plugin API, and runs
as a container.

The Blockbridge volume driver is a full-featured volume plugin for Docker,
enabling multi-host access to block storage data volumes. Many functions are
available through the native Docker API and command line tools. More advanced
functionality is accessible via the API exposed by the Blockbridge Volume
Driver and accompanying command lines tools.

The table below presents the base feature list for 4.0 along with interface support guidelines.

| Blockbridge Feature      | Via Docker API | Via Blockbridge API |
| ------------------------ | :------------: | :-----------------: |
| Create Volume            | Yes            | Yes |
| Inspect Volume           | Yes            | Yes |
| List Volumes             | Yes            | Yes |
| Remove Volume            | Yes            | Yes |
| Secure Transport Volumes | Yes            | Yes |
| Authenticated Volumes    | Yes            | Yes |
| Encrypted Volumes        | Yes            | Yes |
| QoS Volumes              | Yes            | Yes |
| Create Volume Profile    | –              | Yes |
| Inspect Volume Profile   | –              | Yes |
| List Volume Profiles     | –              | Yes |
| Remove Volume Profiles   | –              | Yes |
| Volume Backup            | –              | Yes |
| Volume Restore           | Yes            | Yes |
| Inspect Backup           | –              | Yes |
| List Backups             | –              | Yes |
| Remove Backup            | –              | Yes |


## Quick Start

````
docker-compose up
````

The default compose file will automatically connect to a running Blockbridge storage
simulator.

## Table of Contents 
- [Blockbridge Volume Plugin for Docker](#blockbridge-volume-plugin-for-docker)
    - [Quick Start](#quick-start)
    - [Table of Contents](#table-of-contents)
    - [Configuration](#configuration)
        - [Quick Start](#quick-start)
        - [Additional Configuration required?](#additional-configuration-required)
            - [Start the volume driver](#start-the-volume-driver)
    - [Volume Create](#volume-create)
        - [Volume Options](#volume-options)
            - [User](#user)
            - [Capacity](#capacity)
            - [IOPS](#iops)
        - [Transport](#transport)
    - [OTP](#otp)
            - [From Backup](#from-backup)
        - [Attribute based provisioning](#attribute-based-provisioning)
    - [Volume backup](#volume-backup)
    - [Volume restore](#volume-restore)
    - [Create a volume in Docker (in-band)](#create-a-volume-in-docker-in-band)
        - [Docker volume create (Explicit)](#docker-volume-create-explicit)
        - [Docker volume create (Implicit)](#docker-volume-create-implicit)
        - [Docker run with volume](#docker-run-with-volume)
        - [List volumes with docker](#list-volumes-with-docker)
        - [Inspect volume with docker](#inspect-volume-with-docker)
    - [Create a volume with Blockbridge (out-of-band)](#create-a-volume-with-blockbridge-out-of-band)
        - [Create a volume (out-of-band):](#create-a-volume-out-of-band)
        - [List volumes (out-of-band)](#list-volumes-out-of-band)
        - [Inspect volumes (out-of-band)](#inspect-volumes-out-of-band)
        - [Inspect one volume (out-of-band)](#inspect-one-volume-out-of-band)
        - [Full command help (out-of-band)](#full-command-help-out-of-band)
    - [Volume Profiles](#volume-profiles)
        - [Default profile](#default-profile)
        - [Volume Profiles Provisioning Attributes](#volume-profiles-provisioning-attributes)
            - [(Example) Gold Storage Profile](#example-gold-storage-profile)
            - [(Example) Availability Zone East Profile](#example-availability-zone-east-profile)
            - [(Example) Rack42 Profile](#example-rack42-profile)
        - [List Profiles](#list-profiles)
        - [Inspect one Profile](#inspect-one-profile)
        - [Full command help](#full-command-help)
    - [Volume Backups](#volume-backups)
        - [List backups](#list-backups)
        - [Inspect backup](#inspect-backup)
        - [Remove backup](#remove-backup)
    - [Blockbridge Storage Simulator](#blockbridge-storage-simulator)
    - [What is Blockbridge?](#what-is-blockbridge)
    - [Support](#support)

## Configuration

### Quick Start
For most cases, using the Docker compose file will start the volume
driver, and connect to the Blockbridge simulator.

````
docker-compose up
````

### Additional Configuration required?

For running against Blockbridge storage (not the simulator), or for more
complicated setups, additional configuration may be required.  A startup script
is provided for these cases. 

Two environment variables are required in order to use the startup script:
````
BLOCKBRIDGE_API_HOST
BLOCKBRIDGE_API_KEY
````

Set these environment variables to point to the Blockbridge backend
storage, and to authenticate with the management API.  The Blockbridge
simulator, or any other Blockbridge storage can be configured for use
with the volume driver.

#### Start the volume driver

````
export BLOCKBRIDGE_API_HOST="172.17.42.121"
export BLOCKBRIDGE_API_KEY="1/4pz/TrwO0l53xY8j6VkorTZu2wJEeaaH5PktWI2AxSXynP9OvA7THw"

./bin/blockbridge-docker-volume
````

Confirm the driver is running

````
docker ps
CONTAINER ID        IMAGE                       COMMAND                CREATED              STATUS              PORTS                                      NAMES
f9bba845cc12        blockbridge/volume-driver   "./volume-driver.sh"   About a minute ago   Up About a minute                                              blockbridge-volume-driver
````

## Volume Create

Blockbridge volumes are created by specifying the volume driver type as
'blockbridge'.  The Blockbridge volume driver supports multiple volume options
and provisioning attributes specified.

### Volume Options

The volume is provisioned according to the options specified. The volume type
determines the required options. As Blockbridge is multi-tenant storage, a
**User** is always required.

#### User

The user (tenant) to provision the volume for.

Option name: **user**

#### Capacity

The volume capacity.

Option name: **capacity**

#### IOPS

The volume quality of service (QoS). This is a reserved, guaranteed minimum
IOPS performance of the volume. It requires QoS configuration on the backend.

Option name: **iops**

### Transport

Blockbridge volumes support transport security. Specify `tls` to access your volumes over the network with TLS.

Option name: **transport**

## OTP

If the volume is configured for authentication, specify the one-time-password (OTP) in order to access the volume.

Option name: **otp**

#### From Backup

The volume source to restore from. On volume create, restore from the specified backup.

Option name: **from_backup**

### Attribute based provisioning

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

Option name: **attributes**

## Volume backup

Backup a volume with the volume driver

````
docker exec blockbridge-volume-driver volume backup datavol
````

## Volume restore

Restore a volume that was backed up. Use standard volume create options with a backup source specified.

````
docker volume create --driver blockbridge --name datavol-restore --opt from_backup=datavol-backup
````

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
Blockbridge default volume profile must be setup. If doing an implicit volume
create, a default profile must be setup

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

## Create a volume with Blockbridge (out-of-band)

The Blockbridge volume driver supports out of band volume creation, outside of
Docker.

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
docker exec blockbridge-volume-driver volume inspect 
````

### Inspect one volume (out-of-band)
````
docker exec blockbridge-volume-driver volume inspect --name datavol
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

### Default profile

By naming a profile `default`, it will be used if no options are specified.

Create a default profile:
````
docker exec blockbridge-volume-driver profile create --name default --user block --capacity 32GiB --iops 10000
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

Blockbridge volumes are accessible on any host, with no data copy required.

## Volume Backups

Backups are managed directly via the Blockbridge volume driver. Specify a volume profile
to manage backups for, or with none specified the default is used.

### List backups
List backups for default profile.
````
docker exec blockbridge-volume-driver backup ls
````

List backups for specified profile.
````
docker exec blockbridge-volume-driver backup ls --profile block-profile
````

### Inspect backup
````
docker exec blockbridge-volume-driver backup inspect datavol-backup
````

### Remove backup
````
docker exec blockbridge-volume-driver backup rm datavol-backup
````

## Blockbridge Storage Simulator

The Blockbridge storage backend is available as a simulator running as a Docker
container.

* [blockbridge-simulator](https://github.com/blockbridge/blockbridge-simulator)

## What is Blockbridge?

Blockbridge is Elastic Block Storage for everyone. Run Blockbridge on
bare-metal, on a VM, or in a container, in any cloud, on any provider. Access
your data directly from any Linux or Windows host as a standard block device,
or use it as a Docker volume through the volume plugin in a swarm. Manage your
storage via Web UI, cross-platform command-line tools, or REST API. See
[https://blockbridge.com](https://blockbridge.com) For more information and to
download fully functional trial software, or contact us at info@blockbridge.com
with any questions. We’d love to hear from you!

## Support

Please let us know what you think! Contact us at support@blockbridge.com or on
github.
