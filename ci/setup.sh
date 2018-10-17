#!/bin/bash
set -e

download_logstash() {
  logstash_version=$1
  case "$logstash_version" in
    *-SNAPSHOT)
      wget https://snapshots.elastic.co/downloads/logstash/logstash-$logstash_version.tar.gz
      ;;
    *)
      wget https://artifacts.elastic.co/downloads/logstash/logstash-$logstash_version.tar.gz
      ;;
  esac
}


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