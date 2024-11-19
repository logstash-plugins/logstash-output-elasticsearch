#!/bin/bash

# This is intended to be run the plugin's root directory. `ci/unit/docker-test.sh`
# Ensure you have Docker installed locally and set the ELASTIC_STACK_VERSION environment variable.
set -e

pull_docker_snapshot() {
  project="${1?project name required}"
  local docker_image="docker.elastic.co/${project}/${project}${DISTRIBUTION_SUFFIX}:${ELASTIC_STACK_VERSION}"
  echo "Pulling $docker_image"
  if docker pull "$docker_image" ; then
    echo "docker pull successful"
  else
    case "$ELASTIC_STACK_VERSION_ARG" in
      "8.previous"|"8.current"|"8.next")
        exit 1
        ;;
      *)
        exit 2
        ;;
    esac
  fi
}

VERSION_URL="https://raw.githubusercontent.com/elastic/logstash/main/ci/logstash_releases.json"

if [ -z "${ELASTIC_STACK_VERSION}" ]; then
    echo "Please set the ELASTIC_STACK_VERSION environment variable"
    echo "For example: export ELASTIC_STACK_VERSION=7.x"
    exit 1
fi

# save the original arg if needed
ELASTIC_STACK_VERSION_ARG="$ELASTIC_STACK_VERSION"

echo "Fetching versions from $VERSION_URL"
VERSIONS=$(curl -s $VERSION_URL)

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
elif [[ "$ELASTIC_STACK_VERSION" == "8.next" ]]; then
  # we know "8.next" only exists between FF and GA of a minor
  # exit 1 so the build is skipped
  exit 1
fi

case "${DISTRIBUTION}" in
  default) DISTRIBUTION_SUFFIX="" ;; # empty string when explicit "default" is given
        *) DISTRIBUTION_SUFFIX="${DISTRIBUTION/*/-}${DISTRIBUTION}" ;;
esac
export DISTRIBUTION_SUFFIX

echo "Testing against version: $ELASTIC_STACK_VERSION (distribution: ${DISTRIBUTION:-"default"})"

if [[ "$ELASTIC_STACK_VERSION" = *"-SNAPSHOT" ]]; then
    pull_docker_snapshot "logstash"
    if [ "$INTEGRATION" == "true" ]; then
      pull_docker_snapshot "elasticsearch"
    fi
fi

if [ -f Gemfile.lock ]; then
    rm Gemfile.lock
fi

CURRENT_DIR=$(dirname "${BASH_SOURCE[0]}")

cd .ci

export BUILDKIT_PROGRESS=plain
if [ "$INTEGRATION" == "true" ]; then
    docker-compose down
    docker-compose build --quiet
else
    docker-compose down
    docker-compose build logstash --quiet
fi
