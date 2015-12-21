# Copyright (c) 2015-2016, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

all: volume-driver

volume-driver:
	docker build -t blockbridge/volume-driver .

nocache:
	docker build --no-cache -t blockbridge/volume-driver .
