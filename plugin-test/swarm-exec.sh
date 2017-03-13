#!/bin/bash
set -e

VERSION=17.03.0-ce
SERVICE=

on_exit()
{
    res=$?
    while read -r line; do
        log $line
    done < <(docker service logs $SERVICE)
    docker service rm $(docker service ls -q) >/dev/null 2>&1

    if [ $res -eq 0 ]; then
        log "Command SUCCESS"
    else
        log "Command FAILED"
    fi
}

trap on_exit EXIT

log()
{
    echo "[CMD$$]: $@"

}

log_n()
{
    echo -n "[CMD$$]: $@"
}

# Print command

# pass in constraint to service create
SERVICE_CONSTRAINT=
if [ -n "$CONSTRAINT" ]; then
    export SERVICE_CONSTRAINT="--constraint $CONSTRAINT"
    log "Executing command on node with $SERVICE_CONSTRAINT: $@"
else
    log "Executing command on each node: $@"
fi

# run service create
SERVICE=$(docker service create --mode=global $SERVICE_CONSTRAINT \
          --restart-condition none \
          --mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock \
          blockbridge/swarm-exec:$VERSION "$@")
export SERVICE

log_n "Running tasks..."
while true; do
    if ! OUT=$(docker node ps $(docker node ls -q) | grep Shutdown); then
        echo -n "."
        sleep 1
        continue
    fi
    break
done
echo

log_n "Waiting for tasks to complete..."
while true; do
    if OUT=$(docker node ps $(docker node ls -q) | grep -v 'DESIRED STATE' | grep -v Shutdown); then
        echo -n "."
        sleep 1
        continue
    fi
    break
done
echo

if ! TASKS=$(docker node ps $(docker node ls -q) | grep Shutdown); then
    if [ -z "$TASKS" ]; then
        log "TASKS not found" && exit 1
    fi
fi

if FAILED=$(echo $TASKS | grep Failed); then
    if [ -n "$FAILED" ]; then
        docker node ps --no-trunc $(docker node ls -q)
        log "Service "$@" failed" && exit 1
    fi
fi

exit 0
