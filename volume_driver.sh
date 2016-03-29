#!/bin/bash
###########################################################
# Copyright (c) 2015-2016, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.
###########################################################
# Blockbridge docker volume driver entrypoint
###########################################################

# Validate environment parameters
#: ${BLOCKBRIDGE_API_HOST:?"not set"}

trap '' TERM

# run blockbridge docker volume driver
mkdir -p /run/docker/plugins/blockbridge
ruby -rbundler/setup volume_driver.rb -e production -S /run/docker/plugins/blockbridge/blockbridge.sock
