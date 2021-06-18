ARG ELASTIC_STACK_VERSION
# TODO: refactor this to be implicitly resolved by logstash-plugins/.ci/Dockerfile
FROM docker.elastic.co/logstash/logstash:$ELASTIC_STACK_VERSION
USER logstash
COPY --chown=logstash:logstash Gemfile /usr/share/plugins/plugin/Gemfile
COPY --chown=logstash:logstash *.gemspec VERSION* version* /usr/share/plugins/plugin/
RUN cp /usr/share/logstash/logstash-core/versions-gem-copy.yml /usr/share/logstash/versions.yml
ENV PATH="${PATH}:/usr/share/logstash/vendor/jruby/bin:/usr/share/logstash/jdk/bin"
ENV LOGSTASH_SOURCE="1"
ENV ELASTIC_STACK_VERSION=$ELASTIC_STACK_VERSION
# INTEGRATION="true" while integration testing (false-y by default)
ARG INTEGRATION
ENV INTEGRATION=$INTEGRATION
RUN gem install bundler -v '< 2'
WORKDIR /usr/share/plugins/plugin
RUN bundle install --with test ci
COPY --chown=logstash:logstash . /usr/share/plugins/plugin
RUN bundle exec rake vendor
RUN .ci/setup.sh
