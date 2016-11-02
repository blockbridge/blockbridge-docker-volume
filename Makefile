# Copyright (c) 2015-2016, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

all: volume-driver

volume-driver:
	docker run -e USER=$(shell id -u) --rm -v $(PWD):/usr/src/app blockbridge/volume-driver-build
	docker build -t blockbridge/volume-driver .

tag:
	docker tag blockbridge/volume-driver:latest registry:5000/blockbridge/volume-driver:latest

plugin-tag:
	docker tag blockbridge/volume-driver:latest blockbridge/volume-driver-rootfs:latest

plugin: volume-driver plugin-tag
	$(eval ID = $(shell docker create blockbridge/volume-driver-rootfs:latest true))
	sudo rm -rf plugin/rootfs
	sudo mkdir -p plugin/rootfs
	docker export "$(ID)" | sudo tar -x -C plugin/rootfs
	sudo mkdir -p plugin/rootfs/run/docker/plugins/blockbridge
	sudo mkdir -p plugin/rootfs/ns-net
	sudo mkdir -p plugin/rootfs/ns-mnt
	sudo chmod 777 plugin/rootfs/root
	cp config.json plugin/.
	docker plugin rm -f registry:5000/blockbridge/plugin:latest || true
	sudo docker plugin create registry:5000/blockbridge/plugin plugin
	docker rm -vf "$(ID)"
	docker rmi blockbridge/volume-driver-rootfs

bundle:
	rm -f .bundle/config
	docker run -e USER=$(shell id -u) --rm -v $(PWD):/usr/src/app blockbridge/volume-driver-build bash -c 'bundle && bundle update blockbridge-api && bundle update heroics'

nocache:
	docker build --no-cache -t blockbridge/volume-driver .

readme:
	@md-toc-filter README.md.raw > README.md

.NOTPARALLEL:
