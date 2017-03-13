FROM docker
RUN apk --no-cache add --virtual .deps git \
    && git clone https://github.com/mavenugo/swarm-exec /swarm-exec \
    && apk del .deps
RUN apk --no-cache add curl bash
WORKDIR /swarm-exec
COPY swarm-exec.sh /swarm-exec/
ENV PATH=$PATH:/swarm-exec
ARG VERSION
ENV VERSION=$VERSION
COPY tests setup /tests/
ENV PATH=$PATH:/tests
CMD echo "choose a script: setup, tests"
