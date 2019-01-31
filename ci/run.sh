#!/bin/bash
set -ex

# Set the build dir to ./ if not set by travis
BUILD_DIR=$PWD
if [[ -z "$TRAVIS_BUILD_DIR" && "$TRAVIS_BUILD_DIR" -ne "" ]]; then
  BUILD_DIR=$TRAVIS_BUILD_DIR
fi

export PATH=$BUILD_DIR/gradle/bin:$PATH

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
  # Note that 6.3.0 releases and above do not require an x-pack plugin install

  if [[ "$DISTRIBUTION" == "legacyxpack" ]]; then
    if [[ "$xpack_download_url" == "" ]]; then
      yes y | elasticsearch/bin/elasticsearch-plugin install x-pack
    else
      curl -sL $xpack_download_url > elasticsearch/xpack.zip
      yes y | elasticsearch/bin/elasticsearch-plugin install file://$BUILD_DIR/elasticsearch/xpack.zip
    fi
  fi

  if [[ "$SECURE_INTEGRATION" == "true" ]]; then
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
  fi
  # Needed for travis. On travis the `users` script will fail because it will first try and write
  # to /etc/elasticsearch
  export CONF_DIR=$BUILD_DIR/elasticsearch/config

  if [[ "$DISTRIBUTION" == "default" ]]; then
      elasticsearch/bin/elasticsearch-users useradd simpleuser -p abc123 -r superuser
      elasticsearch/bin/elasticsearch-users useradd 'f@ncyuser' -p 'ab%12#' -r superuser
  elif [[ "$DISTRIBUTION" == "legacyxpack" ]]; then
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

get_es_distribution_version() {
  local version_string=$(elasticsearch/bin/elasticsearch -v -V | tr "," " " | cut -d " " -f 2)
  echo $version_string
}

# Ruby build environment does not have gradle in the env, so we need to download it
# Gradle is added to the PATH in the before_script step and *has* to stay there and
# not here because this script runs in a different bash shell.
download_gradle() {
  echo $PWD
  local version="4.10"
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
  unzip -d $BUILD_DIR distribution/zip/build/distributions/elasticsearch-*.zip
  mv $BUILD_DIR/elasticsearch-* $BUILD_DIR/elasticsearch
  cd $BUILD_DIR
  mkdir -p elasticsearch/config/scripts
  cp $BUILD_DIR/spec/fixtures/scripts/painless/* elasticsearch/config/scripts
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

  if [[ "$DISTRIBUTION" == "oss" ]]; then
    extra_tag_args="$extra_tag_args --tag distribution:oss --tag ~distribution:xpack"
  elif [[ "$DISTRIBUTION" == "default" ]]; then
    extra_tag_args="$extra_tag_args --tag ~distribution:oss --tag distribution:xpack"
  fi

  arch=""

  case "$ARCH" in
     LINUX)
        arch="-linux-86_84"
         ;;
     MAC_OS)
        arch="-darwin-x86_64"
        ;;
     NONE)
        arch=""
        ;;
  esac

  case "$ES_VERSION" in
    LATEST-SNAPSHOT-*)
      split_latest=${ES_VERSION##*-}

      LATEST_ES_VERSION=$(curl -sL https://artifacts-api.elastic.co/v1/versions/ | jq -r --arg LATEST $split_latest '[.versions[] | select(startswith($LATEST))][-1]')
      if [[ "$DISTRIBUTION" == "oss" ]]; then
        setup_es https://snapshots.elastic.co/downloads/elasticsearch/elasticsearch-oss-${LATEST_ES_VERSION}${arch}.tar.gz
      elif [[ "$DISTRIBUTION" == "default" ]]; then
        setup_es https://snapshots.elastic.co/downloads/elasticsearch/elasticsearch-${LATEST_ES_VERSION}${arch}.tar.gz
      fi
      es_distribution_version=$(get_es_distribution_version)
      start_es
      bundle exec rspec -fd $extra_tag_args --tag update_tests:painless --tag update_tests:groovy --tag es_version:$es_distribution_version $spec_path
      ;;

    *-SNAPSHOT)
      if [[ "$DISTRIBUTION" == "oss" ]]; then
        setup_es https://snapshots.elastic.co/downloads/elasticsearch/elasticsearch-oss-${ES_VERSION}${arch}.tar.gz
      elif [[ "$DISTRIBUTION" == "default" ]]; then
        setup_es https://snapshots.elastic.co/downloads/elasticsearch/elasticsearch-${ES_VERSION}${arch}.tar.gz
      fi
      es_distribution_version=$(get_es_distribution_version)
      start_es
      bundle exec rspec -fd $extra_tag_args --tag update_tests:painless --tag update_tests:groovy --tag es_version:$es_distribution_version $spec_path
      ;;
    7.*)
      if [[ "$DISTRIBUTION" == "oss" ]]; then
        setup_es https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-oss-${ES_VERSION}${arch}.tar.gz
      elif [[ "$DISTRIBUTION" == "default" ]]; then
        setup_es https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${ES_VERSION}${arch}.tar.gz
      fi
      es_distribution_version=$(get_es_distribution_version)
      start_es
      bundle exec rspec -fd $extra_tag_args --tag update_tests:painless --tag update_tests:groovy --tag es_version:$es_distribution_version $spec_path
      ;;
    6.[0-2]*)
      setup_es https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${ES_VERSION}.tar.gz https://artifacts.elastic.co/downloads/packs/x-pack/x-pack-${ES_VERSION}.zip
      es_distribution_version=$(get_es_distribution_version)
      start_es
      bundle exec rspec -fd $extra_tag_args --tag update_tests:painless --tag update_tests:groovy --tag es_version:$es_distribution_version $spec_path
      ;;
    6.*)
      if [[ "$DISTRIBUTION" == "oss" ]]; then
        setup_es https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-oss-${ES_VERSION}.tar.gz
      elif [[ "$DISTRIBUTION" == "default" ]]; then
        setup_es https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${ES_VERSION}.tar.gz
      fi
      es_distribution_version=$(get_es_distribution_version)
      start_es
      bundle exec rspec -fd $extra_tag_args --tag update_tests:painless --tag update_tests:groovy --tag es_version:$es_distribution_version $spec_path
      ;;
    5.*)
      setup_es https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${ES_VERSION}.tar.gz
      es_distribution_version=$(get_es_distribution_version)
      start_es -Escript.inline=true -Escript.stored=true -Escript.file=true
      bundle exec rspec -fd $extra_tag_args --tag update_tests:painless --tag update_tests:groovy --tag es_version:$es_distribution_version $spec_path
      ;;
    2.*)
      setup_es https://download.elastic.co/elasticsearch/elasticsearch/elasticsearch-$ES_VERSION.tar.gz
      es_distribution_version=$(get_es_distribution_version)
      start_es -Des.script.inline=on -Des.script.indexed=on -Des.script.file=on
      bundle exec rspec -fd $extra_tag_args --tag update_tests:groovy --tag es_version:$es_distribution_version $spec_path
      ;;
    1.*)
      setup_es https://download.elastic.co/elasticsearch/elasticsearch/elasticsearch-$ES_VERSION.tar.gz
      es_distribution_version=$(get_es_distribution_version)
      start_es -Des.script.inline=on -Des.script.indexed=on -Des.script.file=on
      bundle exec rspec -fd $extra_tag_args --tag es_version:$es_distribution_version $spec_path
      ;;
    *)
      download_gradle
      build_es master
      es_distribution_version=$(get_es_distribution_version)
      start_es
      bundle exec rspec -fd $extra_tag_args --tag update_tests:painless --tag ~update_tests:groovy --tag es_version:$es_distribution_version $spec_path
      ;;
  esac
fi
