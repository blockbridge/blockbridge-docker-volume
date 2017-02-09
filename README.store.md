## Blockbridge Volume Plugin for Docker

The Blockbridge Volume Plugin integrates Docker with Blockbridge
elastic storage using the v2 Docker Plugin API. The plugin provides
access to high-performance storage with advanced security, mobility,
backup and restore capabilities.

## Software Requirements

- Docker Version: ***13.1+***
- Blockbridge Version: ***3.1+***

## Supported Features

Standard management functions are available using the native Docker
tools. Extended storage management functions are available using the
optional Blockbridge Volume Control container. The table below details
the feature sets available using standard and extended APIs and tools.

| Storage Feature          | Native         | Extended |
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


## Installing the Plugin
The Blockbridge Plugin is available on the Docker Hub and in the
Docker Storage. The plugin will need 2 essential pieces of configuration.

### Requirement Parameters
- BLOCKBRIDGE_API_HOST 
- BLOCKBRIDGE_API_KEY

These variables specify the address and authentication meterials
needed for the plugin to communicate with the Blockbridge Storage API.

NOTE: It is ***essential** that you supply an alias when installing a plugin.

````
$ docker plugin install --alias blockbridge blockbridge/volume-plugin \
  BLOCKBRIDGE_API_KEY="1/AZQ+qUfETE2ePp7kR5VOfzFjvaScCZ0iXPUF5uzES3oxlD6pR8RNDA" \
  BLOCKBRIDGE_API_HOST="10.10.10.10"

````
