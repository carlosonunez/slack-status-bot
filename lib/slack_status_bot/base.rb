require 'httparty'

module SlackStatusBot
  module Base
    module Mixins
      def post_new_status!(status:, emoji: nil)
        API.post_status!(status, emoji)
      end

      def post_default_status!
        API.post_status!(ENV['SLACK_API_DEFAULT_STATUS'],
                          ENV['SLACK_API_DEFAULT_STATUS_EMOJI'])
      end

      def weekend?
        weekend_days = [ 'Saturday', 'Sunday' ]
        today = Time.now.getlocal('-06:00').strftime("%A") #TODO: Timezone from TripIt
        current_hour = Time.now.getlocal('-06:00').hour
        weekend_days.include? today || today == 'Friday' and current_hour >= 17
      end

      def limited_availability?
        current_hour = Time.now.getlocal('-06:00').hour # TODO: Get my current time zone from TripIt
        start_hour_of_working_day = 9
        end_hour_of_working_day = 17
        current_hour <= start_hour_of_working_day || current_hour >= end_hour_of_working_day
      end

    end

    module API
      def self.post_status!(status, emoji)
        uri = [ENV['SLACK_API_URL'], 'status'].join('/')
        params = [ "text=#{status}", "emoji=#{emoji}" ].join('&')
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
        return true
      end
    end
  end
end
