#!/bin/bash
set -ex

ES_USER=elastic
ES_PASSWORD=changeme

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
  elasticsearch/bin/elasticsearch -p elasticsearch/bin/elasticsearch.pid $es_args > /tmp/elasticsearch.log 2>/dev/null &
  count=120
  echo "Waiting for elasticsearch to respond..."
  local es_command=curl --silent localhost:9200
  if [[ "$ES_SECURE" == "true" ]]; then
      es_command=curl -u$ES_USER:$ES_PASSWORD --silent localhost:9200
  fi
  while ! $es_command && [[ $count -ne 0 ]]; do
    count=$(( $count - 1 ))
    [[ $count -eq 0 ]] && return 1
    sleep 1
  done
  echo "Elasticsearch is Up !"
  return 0
}

stop_es() {
    pid=$(cat elasticsearch/bin/elasticsearch.pid)
    [ "x$pid" != "x" ] && [ "$pid" -gt 0 ]
    kill -SIGTERM $pid
}

install_shield() {
    elasticsearch/bin/elasticsearch-plugin install x-pack
}

# Setup roles
setup_shield() {
    echo "Creating Logstash role"
    curl -s -POST http://${ES_USER}:${ES_PASSWORD}@localhost:9200/_xpack/security/role/logstash -d '{
      "cluster": ["manage_index_templates"],
      "indices": [
        {
          "names": [ "logstash-*" ],
          "privileges": ["write","delete","create_index"]
        }
      ]
    }'

    echo "Creating Logstash user"
    curl -s -POST http://${ES_USER}:${ES_PASSWORD}@localhost:9200/_xpack/security/user/logstash_user -d '{
      "password" : "changeme",
      "roles" : [ "logstash" ],
      "full_name" : "logstash travis",
      "email" : "abc@example.com"
    }'
}

if [[ "$INTEGRATION" != "true" ]]; then
  bundle exec rspec -fd spec
elif [[ "$ES_SECURE" == "true"]]; then
  setup_es https://download.elastic.co/elasticsearch/release/org/elasticsearch/distribution/tar/elasticsearch/$ES_VERSION/elasticsearch-$ES_VERSION.tar.gz
  install_shield
  start_es
  setup_shield
  bundle exec rspec -fd spec --tag elasticsearch_secure
else
  if [[ "$ES_VERSION" == 5.* ]]; then
    setup_es https://download.elastic.co/elasticsearch/release/org/elasticsearch/distribution/tar/elasticsearch/$ES_VERSION/elasticsearch-$ES_VERSION.tar.gz
    start_es -Escript.inline=true -Escript.stored=true -Escript.file=true
    # Run all tests which are for versions > 5 but don't run ones tagged < 5.x. Include ingest, new template
    bundle exec rspec -fd spec --tag integration --tag version_greater_than_equal_to_5x --tag ~version_less_than_5x
  elif [[ "$ES_VERSION" == 2.* ]]; then
    setup_es https://download.elastic.co/elasticsearch/elasticsearch/elasticsearch-$ES_VERSION.tar.gz
    start_es -Des.script.inline=on -Des.script.indexed=on -Des.script.file=on
    # Run all tests which are for versions < 5 but don't run ones tagged 5.x and above. Skip ingest, new template
    bundle exec rspec -fd spec --tag integration --tag version_less_than_5x --tag ~version_greater_than_equal_to_5x
  else
    setup_es https://download.elastic.co/elasticsearch/elasticsearch/elasticsearch-$ES_VERSION.tar.gz
    start_es -Des.script.inline=on -Des.script.indexed=on -Des.script.file=on
    # Still have to support ES versions < 2.x so run tests for those.
    bundle exec rspec -fd spec --tag integration --tag ~version_greater_than_equal_to_5x --tag ~version_greater_than_equal_to_2x
  fi
fi
