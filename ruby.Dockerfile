FROM ruby:3.2-alpine
MAINTAINER Carlos Nunez <dev@carlosnunez.me>
ARG ENVIRONMENT

RUN apk add --no-cache less grep tzdata bash ruby-dev build-base curl

COPY Gemfile /
RUN bundle install --gemfile /Gemfile
RUN touch /.slack_status_bot_configured

RUN mkdir /scripts
COPY ./scripts/scheduled_status_update.sh /scripts

WORKDIR /app
ENTRYPOINT ["ruby", "-e", "puts 'Welcome to slack-api'"]
