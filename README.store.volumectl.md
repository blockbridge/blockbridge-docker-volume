## Blockbridge Volume Control
*Volume Control* provides extended storage management functions for Docker volumes managed using a Blockbridge Volume *Driver* or Blockbridge Volume *Plugin*.

### Software Requirements
- Volume Plugin or Driver Version: ***3.1+***

### Supported Features
Standard management functions are available using native Docker tools. Extended storage management functions are available using Volume Control. The table below details the feature sets available using standard and extended interfaces.

| Storage Feature          | Standard         | Extended |
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

### Installing Volume Control

The Volume Control commands are packaged as a container and are available through the Docker Store and Docker Hub. The tools automatically discover and connect to a locally running volume driver or plugin. No configuration is required. For ease of use, we do recommend creating an alias as shown below.

````
$ alias volumectl='docker run --rm -v /run/docker/plugins:/run/docker/plugins \
     blockbridge/volumectl'

$ volumectl --help
Usage:
    volumectl [OPTIONS] SUBCOMMAND [ARG] ...

Parameters:
    SUBCOMMAND                    subcommand
    [ARG] ...                     subcommand arguments

Subcommands:
    volume                        manage volumes
    profile                       manage volume profiles
    backup                        manage volume backups

Options:
    -h, --help                    print help

Global options (8 hidden):
    --verbose                     enable verbose output
    --debug                       enable additional debug
    --raw, -R                     enable raw output
    --yaml                        print yaml for raw output
````
