#!/bin/bash
set -e

VERSION_URL="https://raw.githubusercontent.com/elastic/logstash/master/ci/logstash_releases.json"

download_logstash() {
  logstash_version=$1
  wget https://artifacts.elastic.co/downloads/logstash/logstash-$logstash_version.tar.gz
}

translate_version() {
  requested_version=$1
  echo "Fetching versions from $VERSION_URL"
  VERSIONS=$(curl $VERSION_URL)
  RETRIEVED_VERSION=$(echo $VERSIONS | jq '.releases."'"$requested_version"'"')
  if [[ "$RETRIEVED_VERSION" != "null" ]]; then
    # remove starting and trailing double quotes
    RETRIEVED_VERSION="${RETRIEVED_VERSION%\"}"
    RETRIEVED_VERSION="${RETRIEVED_VERSION#\"}"
    echo "Translated $requested_version to ${RETRIEVED_VERSION}"
    export LOGSTASH_VERSION=$RETRIEVED_VERSION
  fi
}


translate_version $LOGSTASH_VERSION
echo "Downloading logstash version: $LOGSTASH_VERSION"
download_logstash $LOGSTASH_VERSION
tar -zxf logstash-$LOGSTASH_VERSION.tar.gz
export LOGSTASH_PATH=$PWD/logstash-${LOGSTASH_VERSION}
export PATH=$LOGSTASH_PATH/vendor/jruby/bin:$LOGSTASH_PATH/vendor/bundle/jruby/1.9.3/bin:$LOGSTASH_PATH/vendor/bundle/jruby/2.3.0/bin:$PATH
export LOGSTASH_SOURCE=1
cp $LOGSTASH_PATH/logstash-core/versions-gem-copy.yml $LOGSTASH_PATH/versions.yml
gem install bundler
jruby -S bundle install --jobs=3 --retry=3 --path=vendor/bundler
jruby -S bundle exec rake vendor
