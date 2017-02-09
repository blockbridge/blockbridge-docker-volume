# Copyright (c) 2015-2017, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.
FROM blockbridge/volume-driver-base
MAINTAINER docker@blockbridge.com
ENV PATH "$PATH:/usr/src/app/exe"
RUN mkdir -p /bb/volumes

COPY . /usr/src/app

CMD ["./volume_driver.sh"]

ARG VERSION
ENV VERSION=$VERSION
