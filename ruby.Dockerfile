FROM ruby:2.7-alpine
MAINTAINER Carlos Nunez <dev@carlosnunez.me>
ARG ENVIRONMENT

RUN apk add --no-cache less grep tzdata

COPY Gemfile /
RUN bundle install --gemfile /Gemfile

WORKDIR /app
ENTRYPOINT ["ruby", "-e", "puts 'Welcome to slack-api'"]
