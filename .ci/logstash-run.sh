#!/bin/bash
set -ex

export PATH=$BUILD_DIR/gradle/bin:$PATH

if [[ "$SECURE_INTEGRATION" == "true" ]]; then
  ES_URL="https://elasticsearch:9200 -k"
else
  ES_URL="http://elasticsearch:9200"
fi

wait_for_es() {
  count=120
  while ! curl -s $ES_URL >/dev/null && [[ $count -ne 0 ]]; do
    count=$(( $count - 1 ))
    [[ $count -eq 0 ]] && exit 1
    sleep 1
  done
  echo $(curl -s $ES_URL | python -c "import sys, json; print(json.load(sys.stdin)['version']['number'])")
}

if [[ "$INTEGRATION" != "true" ]]; then
  bundle exec rspec -fd spec/unit -t ~integration -t ~secure_integration
else

  if [[ "$SECURE_INTEGRATION" == "true" ]]; then
    extra_tag_args="--tag secure_integration"
  else
    extra_tag_args="--tag ~secure_integration --tag integration"
  fi

  echo "Waiting for elasticsearch to respond..."
  ES_VERSION=$(wait_for_es)
  echo "Elasticsearch $ES_VERSION is Up!"
  bundle exec rspec -fd $extra_tag_args --tag update_tests:painless --tag es_version:$ES_VERSION spec/integration
fi
