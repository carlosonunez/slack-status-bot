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
  ignore_expiration_time =
    SlackStatusBot::Listeners::AWSLambda.param_key(event,
                                                   'ignore_expiration_time',
                                                   'false')
  ignore_expiration_time = ignore_expiration_time.downcase == 'true'
  SlackStatusBot.update!(ignore_expiration_time: ignore_expiration_time)
  SlackStatusBot::Listeners::AWSLambda.ok(event)
rescue StandardError => e
  SlackStatusBot::Listeners::AWSLambda.error(
    event,
    message: e,
    http_code: 500
  )
end
