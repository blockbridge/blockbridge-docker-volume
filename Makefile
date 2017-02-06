# Copyright (c) 2015-2016, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

all: driver

driver:
	docker run -e USER=$(shell id -u) --rm -v $(PWD):/usr/src/app blockbridge/volume-driver-build
	docker build -t blockbridge/volume-driver .

tag:
	docker tag blockbridge/volume-driver:latest registry:5000/blockbridge/volume-driver:latest

rootfs-tag:
	docker tag blockbridge/volume-driver:latest blockbridge/plugin-rootfs:latest

plugin: driver rootfs-tag
	$(eval ROOTFS_ID = $(shell docker create blockbridge/plugin-rootfs:latest true))
	sudo rm -rf plugin/rootfs
	sudo mkdir -p plugin/rootfs
	docker export "$(ROOTFS_ID)" | sudo tar -x -C plugin/rootfs
	sudo mkdir -p plugin/rootfs/run/docker/plugins
	sudo mkdir -p plugin/rootfs/bb/mnt
	sudo chmod 777 plugin/rootfs/root
	cp config.json plugin/.
	docker rm -vf "$(ROOTFS_ID)"
	docker rmi blockbridge/plugin-rootfs

plugin-create: plugin
	docker plugin rm -f blockbridge/plugin:latest || true
	docker plugin rm -f registry:5000/blockbridge/plugin:latest || true
	sudo docker plugin create blockbridge/plugin plugin
	sudo docker plugin create registry:5000/blockbridge/plugin plugin

pluginctl:
	docker build -t blockbridge/pluginctl -f Dockerfile.pluginctl .

pluginctl-tag:
	docker tag blockbridge/pluginctl:latest registry:5000/blockbridge/pluginctl:latest

bundle:
	rm -f .bundle/config
	docker run -e USER=$(shell id -u) --rm -v $(PWD):/usr/src/app blockbridge/volume-driver-build bash -c 'bundle && bundle update blockbridge-api && bundle update heroics'

nocache:
	docker build --no-cache -t blockbridge/volume-driver .

readme:
	@md-toc-filter README.md.raw > README.md

.NOTPARALLEL:
