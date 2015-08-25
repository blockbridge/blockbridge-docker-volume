FROM blockbridge/volume-driver-base:onbuild
MAINTAINER docker@blockbridge.com

# run volume driver
CMD ["./volume-driver"]
