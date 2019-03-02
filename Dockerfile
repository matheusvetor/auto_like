# A simple Dockerfile for a RoR application

FROM ruby:2.6.1

RUN apt-get update -qq
RUN apt-get install -y curl build-essential libpq-dev
RUN apt-get update -qq

ENV app /app
RUN mkdir $app
WORKDIR $app
COPY . .

ENV BUNDLE_PATH=/bundle \
    BUNDLE_BIN=/bundle/bin \
    GEM_HOME=/bundle
ENV PATH="${BUNDLE_BIN}:${PATH}"

RUN gem install bundler:2.0.1
RUN bundle install

ADD . $app
