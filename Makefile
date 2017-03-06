# Copyright (c) 2015-2017, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

VERSION_LEVEL  ?= 3.1
VERSION_PATCH  ?= v2
VERSION         = $(VERSION_LEVEL)-$(VERSION_PATCH)
REGISTRY       ?= 
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
VALIDATE_NAME   = plugin-test
VALIDATE_REPO   = $(REGISTRY)$(NAMESPACE)/$(VALIDATE_NAME)
VALIDATE_TAG    = $(VERSION)

default: plugin volumectl

build-all: driver driver-tag plugin plugin-create-all volumectl volumectl-tag

release-all: driver-push plugin-push-all volumectl-push

legacy-driver:
	docker run -e USER=$(shell id -u) --rm -v $(PWD):/usr/src/app blockbridge/volume-driver-build
	docker build -t $(DRIVER_REPO) --build-arg VERSION=$(VERSION) .

legacy-driver-tag:
	docker tag $(DRIVER_REPO):latest $(DRIVER_REPO):$(DRIVER_TAG)
	docker tag $(DRIVER_REPO):latest $(DRIVER_REPO):$(VERSION_LEVEL)

legacy-driver-push:
	docker push $(DRIVER_REPO):latest
	docker push $(DRIVER_REPO):$(DRIVER_TAG)
	docker push $(DRIVER_REPO):$(VERSION_LEVEL)

legacy-all: legacy-driver legacy-driver-tag legacy-driver-push

legacy: legacy-driver legacy-driver-tag

driver-pull:
	docker pull blockbridge/volume-driver:latest-alpine

rootfs-tag:
	docker tag blockbridge/volume-driver:latest-alpine blockbridge/volume-plugin-rootfs:latest

plugin: rootfs-tag
	$(eval ROOTFS_ID = $(shell docker create blockbridge/volume-plugin-rootfs:latest true))
	sudo rm -rf plugin/rootfs
	sudo mkdir -p plugin/rootfs
	docker export "$(ROOTFS_ID)" | sudo tar -x -C plugin/rootfs
	sudo mkdir -p plugin/rootfs/run/docker/plugins
	sudo mkdir -p plugin/rootfs/bb/mnt
	sudo chmod 777 plugin/rootfs/root
	cat config.json | jq -M '.env += [{"name":"VERSION","description":"plugin version","value":"$(VERSION)"}]' | sudo cp /dev/stdin plugin/config.json
	docker rm -vf "$(ROOTFS_ID)"
	docker rmi blockbridge/volume-plugin-rootfs

plugin-create:
	docker plugin rm -f $(PLUGIN_REPO):latest || true
	sudo docker plugin create $(PLUGIN_REPO):latest plugin

plugin-create-all:
	docker plugin rm -f $(PLUGIN_REPO):$(PLUGIN_TAG) || true
	docker plugin rm -f $(PLUGIN_REPO):$(VERSION_LEVEL) || true
	docker plugin rm -f $(PLUGIN_REPO):latest || true
	sudo docker plugin create $(PLUGIN_REPO):$(PLUGIN_TAG) plugin
	sudo docker plugin create $(PLUGIN_REPO):$(VERSION_LEVEL) plugin
	sudo docker plugin create $(PLUGIN_REPO):latest plugin

plugin-push:
	docker plugin push $(PLUGIN_REPO):latest

plugin-push-all:
	docker plugin push $(PLUGIN_REPO):$(PLUGIN_TAG) 
	docker plugin push $(PLUGIN_REPO):$(VERSION_LEVEL) 
	docker plugin push $(PLUGIN_REPO):latest

plugin-all: plugin plugin-create plugin-push

volumectl:
	docker build -t $(VOLUMECTL_REPO) --build-arg VERSION=$(VERSION) -f volumectl/Dockerfile .

volumectl-tag:
	docker tag $(VOLUMECTL_REPO):latest $(VOLUMECTL_REPO):$(VOLUMECTL_TAG)
	docker tag $(VOLUMECTL_REPO):latest $(VOLUMECTL_REPO):$(VERSION_LEVEL)

volumectl-push:
	docker push $(VOLUMECTL_REPO):latest
	docker push $(VOLUMECTL_REPO):$(VOLUMECTL_TAG)
	docker push $(VOLUMECTL_REPO):$(VERSION_LEVEL)

volumectl-all: volumectl volumectl-tag volumectl-push

plugin-test:
	docker build -t $(VALIDATE_REPO) --build-arg VERSION=$(VERSION) -f plugin-test/Dockerfile plugin-test

bundle:
	rm -f .bundle/config
	docker run -e USER=$(shell id -u) --rm -v $(PWD):/usr/src/app blockbridge/volume-driver-build bash -c 'bundle && bundle update blockbridge-api && bundle update heroics'

readme:
	@md-toc-filter README.md.raw > README.md

.PHONY: volumectl plugin-test

.NOTPARALLEL:
