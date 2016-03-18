# Copyright (c) 2015-2016, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.
FROM blockbridge/volume-driver-base
MAINTAINER docker@blockbridge.com

COPY . /usr/src/app

ENV PATH "$PATH:/usr/src/app/exe"

CMD ["./volume_driver.sh"]
