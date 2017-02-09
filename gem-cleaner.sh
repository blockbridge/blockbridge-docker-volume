#!/bin/sh

set -e

rm -rf /usr/local/bundle/cache
find /usr/local/bundle -type d -name ext -print0 | xargs -0 rm -rf
find /usr/local/bundle -type d -name .git -print0 | xargs -0 rm -rf
find /usr/local/bundle -type d -name spec -print0 | xargs -0 rm -rf
find / -type f -name \*.gem -print0 | xargs -0 rm -rf

