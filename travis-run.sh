#!/bin/bash
set -ex

if [[ "$INTEGRATION" != "true" ]]; then
  bundle exec rspec -fd spec
else
  openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=localhost"   -keyout /tmp/localhost.key -out /tmp/localhost.crt
  curl -sL https://download.elastic.co/elasticsearch/elasticsearch/elasticsearch-$ES_VERSION.tar.gz > elasticsearch.tar.gz
  mkdir elasticsearch
  tar -xzf elasticsearch.tar.gz --strip-components=1 -C ./elasticsearch/.
  ln -sn ../../spec/fixtures/scripts elasticsearch/config/.
  elasticsearch/bin/elasticsearch -Des.script.inline=on -Des.script.indexed=on -Des.script.file=on > /tmp/elasticsearch.log &
  sleep 10
  curl http://localhost:9200 && echo "ES is up!" || cat /tmp/elasticsearch.log
  bundle exec rspec -fd spec --tag integration || cat /tmp/elasticsearch.log
fi
