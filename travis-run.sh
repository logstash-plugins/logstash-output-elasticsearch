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
  if [[ ! -d elasticsearch ]]; then
    curl -sL $download_url > elasticsearch.tar.gz
    mkdir elasticsearch
    tar -xzf elasticsearch.tar.gz --strip-components=1 -C ./elasticsearch/.
  fi
  rm -f elasticsearch/config/scripts || true
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

start_nginx() {
  nginx=`which nginx`
  echo "nginx Path: $nginx"

  status_command='curl -k --silent --output /dev/stderr --write-out "%{http_code}" https://simpleuser:abc123@localhost:9900'

  status=$($status_command | tr -d '"')
  echo "Status is |$status|"
  if [[ "$status" -ne "200" ]]; then
    echo "nginx not started ($status)"
    curl -k -i https://simpleuser:abc123@localhost:9900 & true 
    echo "Starting nginx..."
    ./start_nginx.sh &
    sleep 5
    echo "Sending request to nginx"
  fi

  status=$($status_command | tr -d '"')
  if [[ "$status" -eq "200" ]]; then
    echo "nginx started successfully!"
  else
    echo "NGINX could not be started successfully"
    ps aux | grep [n]ginx
    curl -k -i https://simpleuser:abc123@localhost:9900
    exit 1
  fi
}

if [[ "$INTEGRATION" != "true" ]]; then
  bundle exec rspec -fd spec
else
  start_nginx

  if [ "$1" -eq "" ]; then
    spec_path="spec"
  else
    spec_path="$1"
  fi
  if [[ "$ES_VERSION" == 5.* ]]; then
    setup_es https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${ES_VERSION}.tar.gz
    start_es -Escript.inline=true -Escript.stored=true -Escript.file=true
    # Run all tests which are for versions > 5 but don't run ones tagged < 5.x. Include ingest, new template
    bundle exec rspec -fd --tag ~secure_integration --tag integration --tag version_greater_than_equal_to_5x --tag ~version_less_than_5x $spec_path
  elif [[ "$ES_VERSION" == 2.* ]]; then
    setup_es https://download.elastic.co/elasticsearch/elasticsearch/elasticsearch-$ES_VERSION.tar.gz
    start_es -Des.script.inline=on -Des.script.indexed=on -Des.script.file=on
    # Run all tests which are for versions < 5 but don't run ones tagged 5.x and above. Skip ingest, new template
    bundle exec rspec -fd --tag ~secure_integration --tag integration --tag version_less_than_5x --tag ~version_greater_than_equal_to_5x $spec_path
  else
    setup_es https://download.elastic.co/elasticsearch/elasticsearch/elasticsearch-$ES_VERSION.tar.gz
    start_es -Des.script.inline=on -Des.script.indexed=on -Des.script.file=on
    # Still have to support ES versions < 2.x so run tests for those.
    bundle exec rspec -fd --tag ~secure_integration --tag integration --tag ~version_greater_than_equal_to_5x --tag ~version_greater_than_equal_to_2x $spec_path
  fi
fi
