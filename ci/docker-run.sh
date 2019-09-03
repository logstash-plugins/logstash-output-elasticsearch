#!/bin/bash

# This is intended to be run inside the docker container as the command of the docker-compose.
set -ex
if [ "$INTEGRATION" == "true" ]; then
    docker-compose -f ci/docker-compose.yml up --exit-code-from logstash
else
    docker-compose -f ci/docker-compose.yml up --exit-code-from logstash logstash
fi
