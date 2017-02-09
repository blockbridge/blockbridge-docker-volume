# Copyright (c) 2015-2017, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.
FROM blockbridge/volumectl-base
MAINTAINER docker@blockbridge.com
ENV PATH "$PATH:/usr/src/app/exe"

RUN bundle config --global frozen 1

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

COPY volumectl/Gemfile /usr/src/app
COPY volumectl/Gemfile.lock /usr/src/app

COPY gem-cleaner.sh /gem-cleaner.sh
RUN apk --no-cache add --virtual build-deps git bash bison gcc g++ git curl \
    openssl-dev gdb gdbm-dev linux-headers libffi-dev zlib-dev yaml-dev \
    readline-dev ncurses-dev tar make \
    && bundle install --standalone \
    && apk del build-deps \
    && /gem-cleaner.sh

COPY exe /usr/src/app/exe
COPY volumectl /usr/src/app/volumectl
COPY volume_driver/helpers /usr/src/app/volume_driver/helpers
COPY volume_driver/help.rb /usr/src/app/volume_driver/help.rb

ENTRYPOINT ["volumectl"]

ARG VERSION
ENV VERSION=$VERSION
