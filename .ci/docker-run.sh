#!/bin/bash

# This is intended to be run inside the docker container as the command of the docker-compose.
set -ex

cd .ci

if [ "$INTEGRATION" == "true" ]; then
    # remove the `--attach logstash` if you want to see all logs including elasticsearch container logs
    docker compose up --exit-code-from logstash --attach logstash
else
    docker compose up --exit-code-from logstash logstash
fi
