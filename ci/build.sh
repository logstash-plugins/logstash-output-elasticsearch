#!/bin/bash
# version: 1
########################################################
#
# AUTOMATICALLY GENERATED! DO NOT EDIT
#
########################################################
set -e

export LOGSTASH_PATH=$PWD/logstash-${LOGSTASH_VERSION}
source ./ci/setup.sh
export PATH=$LOGSTASH_PATH/vendor/jruby/bin:$LOGSTASH_PATH/vendor/bundle/jruby/1.9.3/bin:$LOGSTASH_PATH/vendor/bundle/jruby/2.3.0/bin:$PATH
export LOGSTASH_SOURCE=1

jruby -S bundle exec rspec