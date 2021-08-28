# frozen_string_literal: true

$LOAD_PATH.unshift('./lib')
require 'slack_status_bot'

def update_from_lambda!(event:, context:)
  SlackStatusBot::Listeners::AWSLambda.update!(event)
rescue StandardError => e
  SlackStatusBot::Listeners::AWSLambda.error(
    event,
    message: e,
    http_code: 500,
    additional_json: {
      details: e.backtrace
    }
  )
end

def run_updates_from_lambda!(event:, context:)
  SlackStatusBot.update!
  SlackStatusBot::Listeners::AWSLambda.ok(event)
rescue StandardError => e
  SlackStatusBot::Listeners::AWSLambda.error(
    event,
    message: e,
    http_code: 500,
    additional_json: {
      details: e.backtrace
    }
  )
end
