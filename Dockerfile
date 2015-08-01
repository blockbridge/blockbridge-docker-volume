FROM ruby:2.1.6-onbuild

# volume plugin directory
RUN mkdir -p /run/docker/plugins/blockbridge

# run volume driver
CMD ["./volume-driver"]
