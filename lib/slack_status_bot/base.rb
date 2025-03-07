# frozen_string_literal: true

require 'httparty'
require 'time'

module SlackStatusBot
  module Base
    module Mixins
      def post_new_status!(status:, emoji: nil, ignore_status_expiration: false)
        if !status_expiration_stale? && !ignore_status_expiration
          return false, "Current status has not expired yet"
        end

        if weekend? && !on_vacation?(status)
          status = 'Yay, weekend!'
          emoji = ':sunglasses:'
          SlackStatusBot.logger.info 'About to yield cuz weekend'
        end
        begin
          API.post_status!(status, emoji)
        rescue StandardError => e
          return false, e
        end
      end

      def post_default_status!(ignore_status_expiration: false)
        if !status_expiration_stale? && !ignore_status_expiration
          return false, "Current status has not expired yet"
        end
        if limited_availability?
          SlackStatusBot.logger.info "Availability limited. Current time is #{Time.now}."
          status = ENV['SLACK_API_DEFAULT_STATUS_LIMITED']
          emoji = ENV['SLACK_API_DEFAULT_STATUS_EMOJI_LIMITED']
        else
          status = ENV['SLACK_API_DEFAULT_STATUS']
          emoji = ENV['SLACK_API_DEFAULT_STATUS_EMOJI']
        end
        if weekend? && !on_vacation?(status)
          status = 'Yay, weekend!'
          emoji = ':sunglasses:'
          SlackStatusBot.logger.info 'About to yield cuz weekend'
        end
        begin
          API.post_status!(status, emoji)
        rescue StandardError => e
          return false, e
        end
      end

      def status_expiration_stale?
        existing_status = API.get_status
        raise 'Unable to get existing status' if existing_status.nil? || existing_status.empty?

        expiration_time = existing_status[:status_expiration] || existing_status['status_expiration']
        current_time = Time.now.strftime('%s').to_i
        expiration_time <= current_time
      end

      # TODO: Move these into a utils class
      def currently_on_vacation?
        status = API.get_status
        if status.nil? || status.empty? || !status.key?(:status_text)
          SlackStatusBot.logger.warn("Can't determine vacation status")
          return false
        end
        on_vacation(status[:status_text])
      end

      def on_vacation?(status)
        return false if status.nil?
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
        result = current_hour < start_hour_of_working_day || current_hour >= end_hour_of_working_day
        SlackStatusBot.logger.debug "Current hour: #{current_hour}, Limited? #{result}"
        result
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
          raise "Unable to retrieve status update: #{response.body}"
        end
        response[:data] || response['data']
      end

      def self.post_status!(status, emoji, expiration = 0)
        if status == nil
          SlackStatusBot.logger.warn "No status given!"
          status = "Hello. world!"
        end
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
          raise "Unable to post status update: #{response.body}"
        end
        true
      end
    end
  end
end
