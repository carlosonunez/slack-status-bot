# frozen_string_literal: true

require 'httparty'
require 'time'

module SlackStatusBot
  module Base
    module Mixins
      def post_new_status!(status:, emoji: nil, ignore_status_expiration: false)
        if !status_expiration_stale? && !ignore_status_expiration
          SlackStatusBot.logger.warn 'Current status has not expired; leaving it alone'
          return false
        end

        if weekend? && !on_vacation?(status)
          status = 'Yay, weekend!'
          emoji = ':sunglasses:'
          SlackStatusBot.logger.info 'About to yield cuz weekend'
        end
        API.post_status!(status, emoji)
      end

      def post_default_status!(ignore_status_expiration: false)
        if !status_expiration_stale? && !ignore_status_expiration
          SlackStatusBot.logger.warn 'Current status has not expired; leaving it alone'
          return false
        end
        status = ENV['SLACK_API_DEFAULT_STATUS']
        emoji = ENV['SLACK_API_DEFAULT_STATUS_EMOJI']
        if weekend? && !on_vacation?(status)
          status = 'Yay, weekend!'
          emoji = ':sunglasses:'
          SlackStatusBot.logger.info 'About to yield cuz weekend'
        end
        API.post_status!(status, emoji)
      end

      def status_expiration_stale?
        existing_status = API.get_status
        raise 'Unable to get existing status' if existing_status.nil? || existing_status.empty?

        expiration_time = existing_status[:status_expiration] || existing_status['status_expiration']
        current_time = Time.now.strftime('%s').to_i
        expiration_time <= current_time
      end

      def on_vacation?(status)
        status.match?(/^Out of office/)
      end

      def weekend?
        weekend_days = %w[Saturday Sunday]
        today = Time.now.strftime('%A') # TODO: Timezone from TripIt
        current_hour = Time.now.hour
        weekend_days.include? today or (today == 'Friday' and current_hour >= 17)
      end

      def limited_availability?
        current_hour = Time.now.hour # TODO: Get my current time zone from TripIt
        start_hour_of_working_day = 9
        end_hour_of_working_day = 17
        current_hour < start_hour_of_working_day || current_hour >= end_hour_of_working_day
      end
    end

    module API
      def self.get_status
        uri = [ENV['SLACK_API_URL'], 'status'].join('/')
        response = HTTParty.get(uri,
                                headers: { 'x-api-key': ENV['SLACK_API_KEY'] })
        SlackStatusBot.logger.debug <<-MESSAGE
        Response code from Slack: #{response.code}, Body: #{response.body}
        MESSAGE
        if response.code != 200
          SlackStatusBot.logger.error "Unable to retrieve status update: #{response.body}"
          return {}
        end
        response[:data] || response['data']
      end

      def self.post_status!(status, emoji, expiration = 0)
        SlackStatusBot.logger.info "Shipping status: #{emoji} #{status}"
        uri = [ENV['SLACK_API_URL'], 'status'].join('/')
        params = ["text=#{status.encode('ASCII')}", "emoji=#{emoji.encode('ASCII')}"].join('&')
        params = "#{params}&expiration=#{expiration}"
        SlackStatusBot.logger.debug "POST to #{uri} with #{params}"
        response = HTTParty.post(uri + '?' + params,
                                 headers: { 'x-api-key': ENV['SLACK_API_KEY'] })
        SlackStatusBot.logger.debug <<-MESSAGE
        Response code from Slack: #{response.code}, Body: #{response.body}
        MESSAGE
        if response.code != 200
          SlackStatusBot.logger.error "Unable to post status update: #{response.body}"
          return false
        end
        true
      end
    end
  end
end
