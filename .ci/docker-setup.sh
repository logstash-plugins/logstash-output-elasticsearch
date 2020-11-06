#!/bin/bash

# This is intended to be run the plugin's root directory. `.ci/docker-setup.sh`
# Ensure you have Docker installed locally and set the ELASTIC_STACK_VERSION environment variable.
set -e

VERSION_URL="https://raw.githubusercontent.com/elastic/logstash/master/ci/logstash_releases.json"


download_and_load_docker_snapshot_artifact() {
  project="${1?project name required}"

  artifact_type="docker-image"
  artifact_name_base="${project}${DISTRIBUTION_SUFFIX}-${ELASTIC_STACK_VERSION}-${artifact_type}"
  echo "Downloading snapshot docker image: ${project}${DISTRIBUTION_SUFFIX} (${ELASTIC_STACK_VERSION})"

  artifact_name_noarch="${artifact_name_base}.tar.gz"
  artifact_name_arch="${artifact_name_base}-x86_64.tar.gz"

  jq_extract_artifact_url=".build.projects.\"${project}\".packages | (.\"${artifact_name_noarch}\" // .\"${artifact_name_arch}\") | .url"

  artifact_list=$(curl --silent "https://artifacts-api.elastic.co/v1/versions/${ELASTIC_STACK_VERSION}/builds/latest")
  artifact_url=$(echo "${artifact_list}" | jq --raw-output "${jq_extract_artifact_url}")

  if [[ "${artifact_url}" == "null" ]]; then
    echo "Failed to find '${artifact_name_noarch}'"
    echo "Failed to find '${artifact_name_arch}'"
    echo "Listing:"
    echo "${artifact_list}" | jq --raw-output ".build.projects.\"${project}\".packages | keys | map(select(contains(\"${artifact_type}\")))"
    return 1
  fi

  echo "${artifact_url}"

  cd /tmp
  curl "${artifact_url}" > "${project}-docker-image.tar.gz"
  tar xfvz "${project}-docker-image.tar.gz" repositories
  echo "Loading ${project} docker image: "
  cat repositories
  docker load < "${project}-docker-image.tar.gz"
  rm "${project}-docker-image.tar.gz"
  cd -
}

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

    case "${DISTRIBUTION}" in
      default) DISTRIBUTION_SUFFIX="" ;; # empty string when explicit "default" is given
            *) DISTRIBUTION_SUFFIX="${DISTRIBUTION/*/-}${DISTRIBUTION}" ;;
    esac
    export DISTRIBUTION_SUFFIX

    echo "Testing against version: $ELASTIC_STACK_VERSION (distribution: ${DISTRIBUTION:-'default'})"

    if [[ "$ELASTIC_STACK_VERSION" = *"-SNAPSHOT" ]]; then
        download_and_load_docker_snapshot_artifact "logstash"
        if [ "$INTEGRATION" == "true" ]; then
          download_and_load_docker_snapshot_artifact "elasticsearch"
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

