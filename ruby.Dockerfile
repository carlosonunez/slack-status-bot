FROM ruby:2.5-alpine
MAINTAINER Carlos Nunez <dev@carlosnunez.me>
ARG ENVIRONMENT

RUN apk add --no-cache less grep

COPY Gemfile /
RUN bundle install --gemfile /Gemfile

WORKDIR /app
ENTRYPOINT ["ruby", "-e", "puts 'Welcome to slack-api'"]
