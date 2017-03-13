set -e

###########################################################
# run tests
###########################################################
docker service rm $(docker service ls -q) >/dev/null 2>&1|| true
export DOCKER_IP=${DOCKER_HOST/tcp:\/\/}
export DOCKER_IP=${DOCKER_IP/:[0-9]*}
docker run --rm -e DOCKER_IP -t -v /var/run/docker.sock:/var/run/docker.sock blockbridge/plugin-test tests
