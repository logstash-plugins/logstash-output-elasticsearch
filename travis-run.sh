#!/bin/bash
set -ex

function finish {
  last_result=$?
  set +e
  [[ $last_result -ne 0 ]] && cat /tmp/elasticsearch.log
}
trap finish EXIT

setup_es() {
  download_url=$1
  curl -sL $download_url > elasticsearch.tar.gz
  mkdir elasticsearch
  tar -xzf elasticsearch.tar.gz --strip-components=1 -C ./elasticsearch/.
  ln -sn ../../spec/fixtures/scripts elasticsearch/config/.
}

start_es() {
  es_args=$@
  elasticsearch/bin/elasticsearch $es_args > /tmp/elasticsearch.log 2>/dev/null &
  count=120
  echo "Waiting for elasticsearch to respond..."
  while ! curl --silent localhost:9200 && [[ $count -ne 0 ]]; do
    count=$(( $count - 1 ))
    [[ $count -eq 0 ]] && return 1
    sleep 1
  done
  echo "Elasticsearch is Up !"
  return 0
}

if [[ "$INTEGRATION" != "true" ]]; then
  bundle exec rspec -fd spec
else
  if [[ "$ES_VERSION" == 5.* ]]; then
    setup_es https://download.elastic.co/elasticsearch/release/org/elasticsearch/distribution/tar/elasticsearch/$ES_VERSION/elasticsearch-$ES_VERSION.tar.gz
    start_es -Escript.inline=true -Escript.stored=true -Escript.file=true
    bundle exec rspec -fd spec --tag integration --tag --tag ~version:less_than_5x
  elif [[ "$ES_VERSION" == 2.* ]]; then
    setup_es https://download.elastic.co/elasticsearch/elasticsearch/elasticsearch-$ES_VERSION.tar.gz
    start_es -Des.script.inline=on -Des.script.indexed=on -Des.script.file=on
    bundle exec rspec -fd spec --tag integration --tag --tag ~version:greater_than_5x
  else
    setup_es https://download.elastic.co/elasticsearch/elasticsearch/elasticsearch-$ES_VERSION.tar.gz
    start_es -Des.script.inline=on -Des.script.indexed=on -Des.script.file=on
    bundle exec rspec -fd spec --tag integration --tag ~greater_than_2x
  fi
fi
