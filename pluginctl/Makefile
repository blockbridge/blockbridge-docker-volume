# Copyright (c) 2015-2016, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

all: pluginctl

pluginctl:
	docker build -t blockbridge/pluginctl -f Dockerfile.pluginctl ..

pluginctl-tag:
	docker tag blockbridge/pluginctl:latest registry:5000/blockbridge/pluginctl:latest

.NOTPARALLEL:
