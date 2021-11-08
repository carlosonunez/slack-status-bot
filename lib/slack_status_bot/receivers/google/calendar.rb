# frozen_string_literal: true

require 'google/apis/calendar_v3'
require 'slack_status_bot/logging'
require 'slack_status_bot/authenticators/google'

module SlackStatusBot
  module Receivers
    module Google
      # This receiver generates statuses from events inside of a Google Calendar.
      # The calendars to monitor must be provided as an environment variable.
      class Calendar
        SCOPES = [
          ::Google::Apis::CalendarV3::AUTH_CALENDAR_EVENTS_READONLY
        ].freeze

        def initialize; end

        def client
          @client = ::Google::Apis::CalendarV3::CalendarService.new
          @client.authorization = @credentials
        end

        def name
          ENV['GOOGLE_CALENDAR_NAME'] or \
            raise 'GOOGLE_CALENDAR_NAME is not defined in your environment'
        end

        # Retrieves stored credentials for the Google client ID in this env
        def credentials
          SlackStatusBot::Authenticators::Google.get_or_create_credentials!(SCOPES)
        end

        # Resolves the Calendar's name to an ID.
        def id
          calendars = @client.list_calendar_lists
                             .items.select! { |cal| cal.summary.downcase == @name.downcase }
          return nil if calendars.length.zero?

          calendars.first.id
        rescue ::Google::Apis::AuthorizationError
          raise SlackStatusBot::Errors::Google::Authentication::AuthInvalid
        end
      end
    end
  end
end
