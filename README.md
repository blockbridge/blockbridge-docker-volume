# Blockbridge Volume Plugin for Docker

[![Try it now](https://www.blockbridge.com/wp-content/uploads/2017/03/docker-certified-plugin-blue-256x256.png?raw=true)][https://blockbridge.com/container/]

Version 3.1

The Blockbridge volume plugin is available as a "Managed Docker Plugin" for
Docker 1.13+ and as a "Legacy Plugin" for Docker 1.12 and earlier. Both options
run as a container. The Managed plugin is preferred, as installation and
lifecycle management of the plugin is taken care of by Docker natively. The
Blockbridge Managed Volume Plugin is available both on the Docker Hub and the
Docker Store as a Docker Certified Plugin.

*Why use a Blockbridge storage backend?*  Blockbridge enables tenant isolation,
automated provisioning, encryption, secure deletion, snapshots and QoS for any
storage backend: on local storage or with any storage vendor over any protocol.

The Blockbridge volume plugin is a full-featured volume plugin for Docker,
enabling multi-host access to block storage data volumes. Many functions are
available through the native Docker API and command line tools. More advanced
functionality is accessible via the API exposed by the Blockbridge Volume
Driver and accompanying command lines tools.

The table below presents the base feature list along with interface support guidelines.

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
$ docker plugin install --alias blockbridge blockbridge/volume-plugin BLOCKBRIDGE_API_HOST="YOUR HOST" \
    BLOCKBRIDGE_API_KEY="YOUR KEY"
````

The plugin requires two environment variables to be set: `BLOCKBRIDGE_API_HOST` to point to the Blockbridge backend, and `BLOCKBRIDGE_API_KEY` as the access token to be used. For a quick-start, use the Blockbridge Storage Container as your backend. Please see [https://github.com/blockbridge/blockbridge-simulator](https://github.com/blockbridge/blockbridge-simulator) for the Blockbridge container quick-start setup.

## Table of Contents 
- [Blockbridge Volume Plugin for Docker](#blockbridge-volume-plugin-for-docker)
    - [Quick Start](#quick-start)
    - [Table of Contents](#table-of-contents)
    - [Configuration](#configuration)
    - [Volumectl](#volumectl)
    - [Volume Create](#volume-create)
        - [Volume Options](#volume-options)
            - [Profile](#profile)
            - [User](#user)
            - [Capacity](#capacity)
            - [Type](#type)
            - [IOPS](#iops)
            - [Transport](#transport)
            - [From Backup](#from-backup)
            - [OTP](#otp)
            - [Attribute based provisioning](#attribute-based-provisioning)
    - [Volume Create Examples](#volume-create-examples)
    - [Create a volume in Docker (in-band)](#create-a-volume-in-docker-in-band)
        - [Docker volume create (Explicit)](#docker-volume-create-explicit)
        - [Docker volume create (Implicit)](#docker-volume-create-implicit)
        - [Docker run with volume](#docker-run-with-volume)
        - [List volumes with docker](#list-volumes-with-docker)
        - [Inspect volume with docker](#inspect-volume-with-docker)
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
        - [Volume backup](#volume-backup)
        - [Volume restore](#volume-restore)
        - [List backups](#list-backups)
        - [Inspect backup](#inspect-backup)
        - [Remove backup](#remove-backup)
    - [Blockbridge Storage Simulator](#blockbridge-storage-simulator)
        - [Legacy Quick Start](#legacy-quick-start)
        - [Additional Configuration required?](#additional-configuration-required)
    - [What is Blockbridge?](#what-is-blockbridge)
    - [Support](#support)

## Configuration

## Volumectl

For full management of the Blockbridge Volume Plugin, use the Blockbridge `volumectl` command, available as a container.

It it recommended to set a shell alias:

`$ alias volumectl='docker run --rm -v /run/docker/plugins:/run/docker/plugins blockbridge/volumectl'`

````
$ volumectl

Usage:
    volumectl [OPTIONS] SUBCOMMAND [ARG] ...

Parameters:
    SUBCOMMAND                    subcommand
    [ARG] ...                     subcommand arguments

Subcommands:
    volume                        manage volumes
    profile                       manage volume profiles
    backup                        manage volume backups
    version                       volumectl version

Global options (8 hidden):
    -h, --help                    print help (use --verbose to show hidden options)
    --verbose                     enable verbose output
    --debug                       enable additional debug
    --raw, -R                     enable raw output
    --yaml                        print yaml for raw output
````

## Volume Create

Create a volume by specifying the driver as `blockbridge` (or the alias you
specified when the plugin was installed). The Blockbridge volume driver
supports multiple volume options and provisioning attributes to be specified.

````
$ volumectl volume create --name testvol
== Volume: testvol
user                  default
capacity              1GiB   
````

### Volume Options

The volume is provisioned according to the options specified.  As Blockbridge
is multi-tenant storage, a **User** is always required. The Blockbridge Storage
Container creates a `default` user for ease-of-use with the plugin.

#### Profile

The storage profile to use for the volume. A storage profile contains volume
create options that make specifying the options easier as a group. See below
for full description. The Blockbridge Storage Container creates a `default`
profile.

If a default profile exists, this parameter is Optional.

Parameter name: **profile**

#### User

Required. The user (tenant) to provision the volume for.

Parameter name: **user**

#### Capacity

Required. The volume capacity.

Parameter name: **capacity**

#### Type

Optional. The volume type. This is defined by the backend and determines
certain volume characteristics, such as IOPS rating, performance, etc.

Parameter name: **type**

#### IOPS

Optional. Depends on `type` specified. The volume quality of service (QoS).
This is a reserved, guaranteed minimum IOPS performance of the volume. It
requires QoS configuration on the backend.

Parameter name: **iops**

#### Transport

Optional. Blockbridge volumes support transport security. Specify `tls` to
access your volumes over the network with TLS.

Parameter name: **transport**

#### From Backup

Optional. The volume source to restore from. On volume create, restore from the
specified backup.

Parameter name: **from_backup**

#### OTP

Optional. If the volume is configured for authentication, specify the
one-time-password (OTP) in order to access the volume.

Parameter name: **otp**

#### Attribute based provisioning

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

Parameter name: **attributes**

## Volume Create Examples

````
$ volumectl volume create --name vol1 --user default --capacity 32GiB --type gp
== Volume: vol1
type                  gp     
user                  default
capacity              32GiB  
````

````
$ volumectl volume create --name vol2 --user default --capacity 32GiB --type provisioned --iops 10000
== Volume: vol2
type                  piops  
user                  default
capacity              100GiB 
iops                  10000
````

````
$ volumectl volume create --name vol3 --user default --capacity 1TiB --type piops --iops 20000
== Volume: vol3
type                  piops  
user                  default
capacity              1TiB   
iops                  20000
````

## Create a volume in Docker (in-band)

There are two ways in Docker to create a volume, either explicitly via *docker
volume create* or implicitly at *docker run* time.

### Docker volume create (Explicit)

Create a blockbridge volume:
````
$ docker volume create --driver blockbridge --name datavol --opt user=block --opt capacity=32GiB
````

### Docker volume create (Implicit)

Once a default profile has been configured (see below), create a blockbridge volume:
````
$ docker run --volume-driver blockbridge -v datavol:/data -it busybox sh
````

NOTE: you cannot pass volume options on the commandline during *docker run*,
these can only be specified explicitly with *docker volume create --opt*, or a
Blockbridge default volume profile must be setup. If doing an implicit volume
create, a default profile must be setup

### Docker run with volume

Reference existing Blockbridge volume at docker run:
````
$ docker run -v datavol:/data -it busybox sh
````

### List volumes with docker
````
$ docker volume ls
````

### Inspect volume with docker
````
$ docker volume inspect datavol
````

## Volume Profiles

Blockbridge volume profiles are a way to describe different sets of volume
options and provisioning attributes as a **Storage Profile** or **Storage
Template**.  Instead of specifying each individual option every time a volume is
created, a volume profile can be referenced.

Create a profile with the volume driver:
````
$ volumectl profile create --name profile-test --user default --capacity 32GiB
== Profile: profile-test
user                  default 
capacity              32GiB   
transport             insecure

````

Reference the profile to create a volume. Each volume that uses this
**profiletest** will be created for the **default** user with a capacity of
**32GiB**.
````
$ docker volume create --driver blockbridge --name datavol2 --opt profile=profile-test
````

### Default profile

By naming a profile `default`, it will be used if no other profile is
specified. NOTE: the Blockbridge Storage Container already creates a `default`
profile.

Create a default profile:
````
$ volumectl profile create --name default --user default --capacity 32GiB --type gp2
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
$ volumectl profile create --name gold --user default --type provisioned-iops --iops 10000 --capacity 1TiB +ssd +production +multipath +high-iops
````

#### (Example) Availability Zone East Profile
````
$ volumectl profile create --name us-east --user default --capacity 10GiB +us-east +ssd -production
````

#### (Example) Rack42 Profile
````
$ volumectl profile create profile create --name rack42 --user block --capacity 16GiB +rack42
````

### List Profiles
````
$ volumectl profile ls
````

### Inspect one Profile
````
$ volumectl profile inspect rack42
````

### Full command help
````
$ volumectl profile --help
````

Blockbridge volumes are accessible on any host, with no data copy required.

## Volume Backups

Backup any volume directly to any S3-compatible object store. Your filesystem
is frozen, a snapshot is taken, and your block device is converted to objects.
All operations take place on the Blockbridge backend, so your backup is taken
directly from your data. No host dependencies are required, and if your host
crashes during your backup, the backup still takes place successfully.  Backups
are managed directly via the Blockbridge volume driver. Specify a volume
profile to manage backups for, or with none specified the default is used.

### Volume backup

Backup a volume with the volume driver

````
$ volumectl backup testvol
````

### Volume restore

Restore a volume that was backed up. Use standard volume create options with a backup source specified.

````
$ volumectl volume create --name testvol-restore --from-backup testvol-backup
````

### List backups
List backups for default profile.
````
$ volumectl backup ls
````

List backups for specified profile.
````
$ volumectl backup ls --profile profile-test
````

### Inspect backup
````
$ volumectl backup inspect datavol-backup
````

### Remove backup
````
$ volumectl backup rm datavol-backup
````

## Blockbridge Storage Simulator

The Blockbridge storage backend is available as a simulator running as a Docker
container.

* [blockbridge-simulator](https://github.com/blockbridge/blockbridge-simulator)

### Legacy Quick Start
For Docker version 1.12 or earlier, the Blockbridge Volume Driver is available
as a legacy plugin. A compose file is available to start the driver (as a
container).  For most cases, using the Docker compose file will start the
volume driver, and connect to the Blockbridge simulator.

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

## What is Blockbridge?

Blockbridge is Elastic Block Storage for everyone. Run Blockbridge on
bare-metal, on a VM, or in a container, in any cloud, on any provider. Access
your data directly from any Linux or Windows host as a standard block device,
or use it as a Docker volume through the volume plugin in a swarm. Manage your
storage via Web UI, cross-platform command-line tools, or REST API. See
[https://blockbridge.com](https://blockbridge.com) for more information and to
download fully functional trial software, or contact us at info@blockbridge.com
with any questions. We’d love to hear from you!

## Support

Please let us know what you think! Contact us at support@blockbridge.com or on
github.
