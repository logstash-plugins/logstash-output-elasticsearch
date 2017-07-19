#!/bin/bash
set -ex

export PATH=$PATH:$TRAVIS_BUILD_DIR/gradle/bin/

# Set the build dir to ./ if not set by travis
BUILD_DIR=$PWD
if [[ -z "$TRAVIS_BUILD_DIR" && "$TRAVIS_BUILD_DIR" -ne "" ]]; then
	BUILD_DIR=$TRAVIS_BUILD_DIR
fi

function finish {
  last_result=$?
  set +e
  [[ $last_result -ne 0 ]] && cat /tmp/elasticsearch.log
}
trap finish EXIT

setup_es() {
  download_url=$1
  xpack_download_url=$2
  if [[ ! -d elasticsearch ]]; then
    curl -sL $download_url > elasticsearch.tar.gz
    mkdir elasticsearch
    tar -xzf elasticsearch.tar.gz --strip-components=1 -C ./elasticsearch/.
  fi
  rm -f elasticsearch/config/scripts || true
  mkdir -p elasticsearch/config/scripts
  cp $BUILD_DIR/spec/fixtures/scripts/groovy/* elasticsearch/config/scripts
  cp $BUILD_DIR/spec/fixtures/scripts/painless/* elasticsearch/config/scripts

  # If we're running with xpack SSL/Users enabled...
  if [[ "$SECURE_INTEGRATION" == "true" ]]; then
    if [[ "$xpack_download_url" == "" ]]; then
      yes y | elasticsearch/bin/elasticsearch-plugin install x-pack
    else
      curl -sL $xpack_download_url > elasticsearch/xpack.zip
      yes y | elasticsearch/bin/elasticsearch-plugin install file://$BUILD_DIR/elasticsearch/xpack.zip
    fi

    es_yml=elasticsearch/config/elasticsearch.yml
    cp -rv $BUILD_DIR/spec/fixtures/test_certs elasticsearch/config/test_certs
    echo "xpack.security.http.ssl.enabled: true" >> $es_yml
    echo "xpack.ssl.key: $BUILD_DIR/elasticsearch/config/test_certs/test.key" >> $es_yml
    echo "xpack.ssl.certificate: $BUILD_DIR/elasticsearch/config/test_certs/test.crt" >> $es_yml
    echo "xpack.ssl.certificate_authorities: [ '$BUILD_DIR/elasticsearch/config/test_certs/ca/ca.crt' ]" >> $es_yml
  fi
}

start_es() {
  es_args=$@
  elasticsearch/bin/elasticsearch $es_args > /tmp/elasticsearch.log 2>/dev/null &
  count=120
  echo "Waiting for elasticsearch to respond..."
  es_url="http://localhost:9200" 
  if [[ "$SECURE_INTEGRATION" == "true" ]]; then
    es_url="https://localhost:9200 -k"

    elasticsearch/bin/x-pack/users useradd simpleuser -p abc123 -r superuser
    elasticsearch/bin/x-pack/users useradd 'f@ncyuser' -p 'ab%12#' -r superuser
  fi

  while ! curl --silent $es_url && [[ $count -ne 0 ]]; do
    count=$(( $count - 1 ))
    [[ $count -eq 0 ]] && return 1
    sleep 1
  done
  echo "Elasticsearch is Up !"

  return 0
}

# Ruby build environment does not have gradle in the env, so we need to download it
# Gradle is added to the PATH in the before_script step and *has* to stay there and
# not here because this script runs in a different bash shell.
download_gradle() {
  echo $PWD
  local version="3.3"
  curl -sL https://services.gradle.org/distributions/gradle-$version-bin.zip > gradle.zip
  unzip -d . gradle.zip
  mv gradle-* gradle
}

# Builds any branch of ES and runs tests against it. Default is master
build_es() {
  branch=$1
  git clone https://github.com/elastic/elasticsearch.git es_src
  cd es_src
  gradle :distribution:zip:assemble
  unzip -d $TRAVIS_BUILD_DIR distribution/zip/build/distributions/elasticsearch-*.zip
  mv $TRAVIS_BUILD_DIR/elasticsearch-* $TRAVIS_BUILD_DIR/elasticsearch
  cd $TRAVIS_BUILD_DIR
  mkdir -p elasticsearch/config/scripts
  cp $TRAVIS_BUILD_DIR/spec/fixtures/scripts/painless/* elasticsearch/config/scripts
}

start_nginx() {
  ./start_nginx.sh &
  sleep 5
}

bundle install
if [[ "$INTEGRATION" != "true" ]]; then
  bundle exec rspec -fd spec -t ~integration  -t ~secure_integration
else
  if [[ "$1" -eq "" ]]; then
    spec_path="spec"
  else
    spec_path="$1"
  fi

  extra_tag_args="--tag ~secure_integration --tag integration"
  if [[ "$SECURE_INTEGRATION" == "true" ]]; then
    extra_tag_args="--tag secure_integration"
  fi

  case "$ES_VERSION" in
      6.*)
        setup_es https://snapshots.elastic.co/downloads/elasticsearch/elasticsearch-${ES_VERSION}-SNAPSHOT.tar.gz https://snapshots.elastic.co/downloads/packs/x-pack/x-pack-$ES_VERSION-SNAPSHOT.zip
        start_es
        # Run all tests which are for versions > 5 but don't run ones tagged < 5.x. Include ingest, new template
        bundle exec rspec -fd $extra_tag_args --tag version_greater_than_equal_to_5x --tag update_tests:painless --tag update_tests:groovy --tag ~version_less_than_5x $spec_path
        ;;
      5.*)
          setup_es https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${ES_VERSION}.tar.gz
          start_es -Escript.inline=true -Escript.stored=true -Escript.file=true
          # Run all tests which are for versions > 5 but don't run ones tagged < 5.x. Include ingest, new template
          bundle exec rspec -fd $extra_tag_args --tag version_greater_than_equal_to_5x --tag update_tests:painless --tag update_tests:groovy --tag ~version_less_than_5x $spec_path
          ;;
      2.*)
          setup_es https://download.elastic.co/elasticsearch/elasticsearch/elasticsearch-$ES_VERSION.tar.gz
          start_es -Des.script.inline=on -Des.script.indexed=on -Des.script.file=on
          # Run all tests which are for versions < 5 but don't run ones tagged 5.x and above. Skip ingest, new template
          bundle exec rspec -fd $extra_tag_args --tag version_less_than_5x --tag update_tests:groovy --tag ~version_greater_than_equal_to_5x $spec_path
          ;;
      1.*)
          setup_es https://download.elastic.co/elasticsearch/elasticsearch/elasticsearch-$ES_VERSION.tar.gz
          start_es -Des.script.inline=on -Des.script.indexed=on -Des.script.file=on
          # Still have to support ES versions < 2.x so run tests for those.
          bundle exec rspec -fd $extra_tag_args --tag ~version_greater_than_equal_to_5x --tag ~version_greater_than_equal_to_2x $spec_path
          ;;
      *)
          download_gradle
          build_es master
          start_es
          bundle exec rspec -fd $extra_tag_args --tag version_greater_than_equal_to_5x --tag update_tests:painless --tag ~update_tests:groovy --tag ~version_less_than_5x $spec_path
          ;;
  esac
fi
