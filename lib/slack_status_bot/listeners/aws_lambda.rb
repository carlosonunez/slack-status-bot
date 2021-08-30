# frozen_string_literal: true

require 'chronic_duration'

module SlackStatusBot
  module Listeners
    # This is a listener for invocations of `status` made through AWS Lambda via API Gateway.
    class AWSLambda
      # Post an update from AWS Lambda.
      def self.update!(event)
        params = params(event)
        missing = %w[status emoji].filter { |p| !params.key?(p.to_sym) }
        if missing.length.positive?
          error(event, message: "Please provide: #{missing.join(', ')}")
        elsif SlackStatusBot::Base::API.post_status!(params[:status],
                                                     params[:emoji],
                                                     expiration(params[:expiration]))
          ok(event)
        else
          error(event, message: 'Update failed; check logs')
        end
      end

      def self.expiration(expiration_time)
        return 0 if expiration_time.nil?

        cutoff = 1_000_000_000
        parsed = ChronicDuration.parse(expiration_time.to_s)
        return Time.now.strftime('%s').to_i + parsed if parsed < cutoff
        return parsed if parsed >= cutoff
      end

      # Retrieve parameters provided from an AWS Lambda event object.
      # Documentation on this object is sparse and language-specific, but this is a
      # good place to start:
      # https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-method-settings-method-request.html#setup-method-request-parameters
      def self.params(event = {})
        body_params = JSON.parse(get_key_from_sym_or_string(event, 'body', '{}'),
                                 symbolize_names: true)
        return body_params unless body_params.empty?

        query_params = get_key_from_sym_or_string(event, 'queryStringParameters', {})
        query_params.transform_keys(&:to_sym)
      end

      def self.param_key(event, key, default = nil)
        get_key_from_sym_or_string(params(event), key, default)
      end

      def self.get_key_from_sym_or_string(hash, key, default = nil)
        hash[key.to_sym] || hash[key.to_s] || default
      end

      def self.trace_id(event)
        return 'NO_TRACE_ID' unless params(event).key?(:headers) &&
                                    params(event)[:headers].key?('X-Amzn-Trace-Id')

        params(event)[:headers]['X-Amzn-Trace-Id']
      end

      # Send a success message in an API Gateway compatible payload.
      def self.ok(event)
        SlackStatusBot.logger.debug("[#{trace_id(event)}] sending ok")
        {
          statusCode: 200,
          headers: {
            'Content-Type': 'application/json'
          },
          body: {
            status: 'ok'
          }.to_json
        }
      end

      # Send an error in an API Gateway compatible payload.
      def self.error(event, http_code: 422, message: '', additional_json: {})
        SlackStatusBot.logger.error("[#{trace_id(event)}] sending error: #{message}")
        body = {
          status: 'error'
        }
        body[:additional] = additional_json unless additional_json.empty?
        body[:message] = message.to_s
        {
          statusCode: http_code,
          headers: {
            'Content-Type': 'application/json'
          },
          body: body.to_json
        }
      end

      def self.parse_expiration_time(time_string)
        return time_string.to_i unless time_string.match?(/(\d+)(\w)/)

        duration = 0
        time_string.scan(/(\d+)(\w)/).each do |amount, token|
          seconds = case token
                    when 'm'
                      60
                    when 'h'
                      (60 * 60)
                    when 'd'
                      (60 * 60 * 24)
                    else
                      1
                    end
          duration += amount.to_i * seconds
        end
        duration
      end
    end
  end
end
