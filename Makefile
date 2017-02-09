# Copyright (c) 2015-2017, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

VERSION_LEVEL  ?= 3.1
VERSION_PATCH  ?= v1
VERSION         = $(VERSION_LEVEL)-$(VERSION_PATCH)
REGISTRY       ?= ""
NAMESPACE       = blockbridge
PLUGIN_NAME     = volume-plugin
PLUGIN_REPO     = $(REGISTRY)$(NAMESPACE)/$(PLUGIN_NAME)
PLUGIN_TAG      = $(VERSION)
DRIVER_NAME     = volume-driver
DRIVER_REPO     = $(REGISTRY)$(NAMESPACE)/$(DRIVER_NAME)
DRIVER_TAG      = $(VERSION)
VOLUMECTL_NAME  = volumectl
VOLUMECTL_REPO  = $(REGISTRY)$(NAMESPACE)/$(VOLUMECTL_NAME)
VOLUMECTL_TAG   = $(VERSION)

all: plugin volumectl

driver:
	docker run -e USER=$(shell id -u) --rm -v $(PWD):/usr/src/app blockbridge/volume-driver-build
	docker build -t $(DRIVER_REPO) --build-arg VERSION=$(VERSION) .

driver-tag:
	docker tag $(DRIVER_REPO):latest $(DRIVER_REPO):$(DRIVER_TAG)
	docker tag $(DRIVER_REPO):latest $(DRIVER_REPO):$(VERSION_LEVEL)

driver-push:
	docker push $(DRIVER_REPO):latest
	docker push $(DRIVER_REPO):$(DRIVER_TAG)
	docker push $(DRIVER_REPO):$(VERSION_LEVEL)

rootfs-tag:
	docker tag blockbridge/volume-driver:latest blockbridge/volume-plugin-rootfs:latest

plugin: driver rootfs-tag
	$(eval ROOTFS_ID = $(shell docker create blockbridge/volume-plugin-rootfs:latest true))
	sudo rm -rf plugin/rootfs
	sudo mkdir -p plugin/rootfs
	docker export "$(ROOTFS_ID)" | sudo tar -x -C plugin/rootfs
	sudo mkdir -p plugin/rootfs/run/docker/plugins
	sudo mkdir -p plugin/rootfs/bb/mnt
	sudo chmod 777 plugin/rootfs/root
	cp config.json plugin/.
	docker rm -vf "$(ROOTFS_ID)"
	docker rmi blockbridge/volume-plugin-rootfs

plugin-create:
	docker plugin rm -f $(PLUGIN_REPO):$(PLUGIN_TAG) || true
	sudo docker plugin create $(PLUGIN_REPO):$(PLUGIN_TAG) plugin

volumectl:
	docker build -t $(VOLUMECTL_REPO) --build-arg VERSION=$(VERSION) -f volumectl/Dockerfile .

volumectl-tag:
	docker tag $(VOLUMECTL_REPO):latest $(VOLUMECTL_REPO):$(VOLUMECTL_TAG)
	docker tag $(VOLUMECTL_REPO):latest $(VOLUMECTL_REPO):$(VERSION_LEVEL)

volumectl-push:
	docker push $(VOLUMECTL_REPO):latest
	docker push $(VOLUMECTL_REPO):$(VOLUMECTL_TAG)
	docker push $(VOLUMECTL_REPO):$(VERSION_LEVEL)

bundle:
	rm -f .bundle/config
	docker run -e USER=$(shell id -u) --rm -v $(PWD):/usr/src/app blockbridge/volume-driver-build bash -c 'bundle && bundle update blockbridge-api && bundle update heroics'

readme:
	@md-toc-filter README.md.raw > README.md

.PHONY: volumectl

.NOTPARALLEL:
