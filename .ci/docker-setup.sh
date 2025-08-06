#!/bin/bash

# This is intended to be run the plugin's root directory. `ci/unit/docker-test.sh`
# Ensure you have Docker installed locally and set the ELASTIC_STACK_VERSION environment variable.
set -e

pull_docker_snapshot() {
  project="${1?project name required}"
  stack_version_alias="${2?stack version alias required}"
  local docker_image="docker.elastic.co/${project}/${project}${DISTRIBUTION_SUFFIX}:${ELASTIC_STACK_VERSION}"
  echo "Pulling $docker_image"
  if docker pull "$docker_image" ; then
    echo "docker pull successful"
  else
    case $stack_version_alias in
      "8.previous"|"8.current"|"9.previous"|"9.current"|"9.next")
        exit 99
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
    echo "For example: export ELASTIC_STACK_VERSION=9.x"
    exit 1
fi

# The ELASTIC_STACK_VERSION may be an alias, save the original before translating it
ELASTIC_STACK_VERSION_ALIAS="$ELASTIC_STACK_VERSION"

echo "Computing latest stream version"
VERSION_CONFIG_FILE="$(dirname "$0")/logstash-versions.yml"
if [[ "$SNAPSHOT" = "true" ]]; then
  ELASTIC_STACK_RETRIEVED_VERSION=$(ruby -r yaml -e "puts YAML.load_file('$VERSION_CONFIG_FILE')['snapshots']['$ELASTIC_STACK_VERSION']")
else
  ELASTIC_STACK_RETRIEVED_VERSION=$(ruby -r yaml -e "puts YAML.load_file('$VERSION_CONFIG_FILE')['releases']['$ELASTIC_STACK_VERSION']")
fi

if [[ -n "$ELASTIC_STACK_RETRIEVED_VERSION" ]]; then
  echo "Translating ELASTIC_STACK_VERSION to ${ELASTIC_STACK_RETRIEVED_VERSION}"
  export ELASTIC_STACK_VERSION=$ELASTIC_STACK_RETRIEVED_VERSION
elif [[ "$ELASTIC_STACK_VERSION" == "9.next" ]]; then
  exit 99
else
  # No version translation found, assuming user provided explicit version
  echo "No version found for $ELASTIC_STACK_VERSION, using as-is"
fi

case "${DISTRIBUTION}" in
  default) DISTRIBUTION_SUFFIX="" ;; # empty string when explicit "default" is given
        *) DISTRIBUTION_SUFFIX="${DISTRIBUTION/*/-}${DISTRIBUTION}" ;;
esac
export DISTRIBUTION_SUFFIX

echo "Testing against version: $ELASTIC_STACK_VERSION (distribution: ${DISTRIBUTION:-"default"})"

if [[ "$ELASTIC_STACK_VERSION" = *"-SNAPSHOT" ]]; then
    pull_docker_snapshot "logstash" $ELASTIC_STACK_VERSION_ALIAS
    if [ "$INTEGRATION" == "true" ]; then
      pull_docker_snapshot "elasticsearch" $ELASTIC_STACK_VERSION_ALIAS
    fi
fi

if [ -f Gemfile.lock ]; then
    rm Gemfile.lock
fi

CURRENT_DIR=$(dirname "${BASH_SOURCE[0]}")

cd .ci

export BUILDKIT_PROGRESS=plain
if [ "$INTEGRATION" == "true" ]; then
    docker compose down
    docker compose build
else
    docker compose down
    docker compose build logstash
fi
