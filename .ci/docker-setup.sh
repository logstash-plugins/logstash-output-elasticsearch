#!/bin/bash

# This is intended to be run the plugin's root directory. `.ci/docker-setup.sh`
# Ensure you have Docker installed locally and set the ELASTIC_STACK_VERSION environment variable.
set -e

VERSION_URL="https://raw.githubusercontent.com/elastic/logstash/master/ci/logstash_releases.json"

if [ "$ELASTIC_STACK_VERSION" ]; then
    echo "Fetching versions from $VERSION_URL"
    VERSIONS=$(curl --silent $VERSION_URL)
    if [[ "$SNAPSHOT" = "true" ]]; then
      ELASTIC_STACK_RETRIEVED_VERSION=$(echo $VERSIONS | jq '.snapshots."'"$ELASTIC_STACK_VERSION"'"')
      echo $ELASTIC_STACK_RETRIEVED_VERSION
    else
      ELASTIC_STACK_RETRIEVED_VERSION=$(echo $VERSIONS | jq '.releases."'"$ELASTIC_STACK_VERSION"'"')
    fi
    if [[ "$ELASTIC_STACK_RETRIEVED_VERSION" != "null" ]]; then
      # remove starting and trailing double quotes
      ELASTIC_STACK_RETRIEVED_VERSION="${ELASTIC_STACK_RETRIEVED_VERSION%\"}"
      ELASTIC_STACK_RETRIEVED_VERSION="${ELASTIC_STACK_RETRIEVED_VERSION#\"}"
      echo "Translated $ELASTIC_STACK_VERSION to ${ELASTIC_STACK_RETRIEVED_VERSION}"
      export ELASTIC_STACK_VERSION=$ELASTIC_STACK_RETRIEVED_VERSION
    fi

    if [[ "$DISTRIBUTION" = "oss" ]]; then
      export DISTRIBUTION_SUFFIX="-oss"
    else
      export DISTRIBUTION_SUFFIX=""
    fi

    echo "Testing against version: $ELASTIC_STACK_VERSION"

    if [[ "$ELASTIC_STACK_VERSION" = *"-SNAPSHOT" ]]; then
        cd /tmp

        jq=".build.projects.\"logstash\".packages.\"logstash$DISTRIBUTION_SUFFIX-$ELASTIC_STACK_VERSION-docker-image.tar.gz\".url"
        result=$(curl --silent https://artifacts-api.elastic.co/v1/versions/$ELASTIC_STACK_VERSION/builds/latest | jq -r $jq)
        echo $result
        curl $result > logstash-docker-image.tar.gz
        tar xfvz logstash-docker-image.tar.gz  repositories
        echo "Loading docker image: "
        cat repositories
        docker load < logstash-docker-image.tar.gz
        rm logstash-docker-image.tar.gz
        cd -

        if [ "$INTEGRATION" == "true" ]; then

          cd /tmp

          jq=".build.projects.\"elasticsearch\".packages.\"elasticsearch$DISTRIBUTION_SUFFIX-$ELASTIC_STACK_VERSION-docker-image.tar.gz\".url"
          result=$(curl --silent https://artifacts-api.elastic.co/v1/versions/$ELASTIC_STACK_VERSION/builds/latest | jq -r $jq)
          echo $result
          curl $result > elasticsearch-docker-image.tar.gz
          tar xfvz elasticsearch-docker-image.tar.gz  repositories
          echo "Loading docker image: "
          cat repositories
          docker load < elasticsearch-docker-image.tar.gz
          rm elasticsearch-docker-image.tar.gz
          cd -

        fi
    fi

    if [ -f Gemfile.lock ]; then
        rm Gemfile.lock
    fi

    cd .ci

    if [ "$INTEGRATION" == "true" ]; then
        docker-compose down
        docker-compose build
    else
        docker-compose down
        docker-compose build logstash
    fi
else
    echo "Please set the ELASTIC_STACK_VERSION environment variable"
    echo "For example: export ELASTIC_STACK_VERSION=6.2.4"
    exit 1
fi

