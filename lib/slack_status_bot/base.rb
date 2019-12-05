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
