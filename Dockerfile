FROM ruby:2.7.6-alpine

ENV RUBYGEMS_VERSION=3.3.21
ENV BUNDLER_VERSION=2.3.21

WORKDIR /app

# throw errors if Gemfile has been modified since Gemfile.lock
RUN echo "gem: --no-document" >> /etc/gemrc \
  && bundle config --global disable_shared_gems false \
  && gem update --system "$RUBYGEMS_VERSION" \
  && gem install bundler --version "$BUNDLER_VERSION" \
  && apk add --no-cache \
    curl \
    less \
    libxml2-dev \
    libxslt-dev \
    nodejs \
    tzdata

COPY [".ruby-version", "Gemfile", "Gemfile.lock", "/app/"]

RUN apk add --no-cache --virtual build-dependencies build-base \
  && bundle config build.nokogiri --use-system-libraries \
  && bundle config set without 'no_docker' \
  && bundle install -j "$(getconf _NPROCESSORS_ONLN)" --retry 5 \
  && bundle clean --force \
  && apk del build-dependencies

COPY . /app

RUN RAILS_ENV=production bundle exec rake assets:precompile \
  && rm -rf /app/tmp/* \
  && chmod 777 /app/tmp

ENV RAILS_ENV production

ENV RAILS_LOG_TO_STDOUT true

ENV RAILS_SERVE_STATIC_FILES true

EXPOSE 8080

HEALTHCHECK CMD curl --fail "http://$(/bin/hostname -i | /usr/bin/awk '{ print $1 }'):${PORT:-8080}/users/sign_in" || exit 1

CMD ["bundle", "exec", "puma", "-C", "config/puma.default.rb"]

