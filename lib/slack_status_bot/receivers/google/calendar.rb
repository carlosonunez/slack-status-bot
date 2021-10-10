# frozen_string_literal: true

require 'google/apis/calendar_v3'
require 'slack_status_bot/authenticators/google'

module SlackStatusBot
  module Receivers
    module Google
      # This receiver generates statuses from events inside of a Google Calendar.
      # The calendars to monitor must be provided as an environment variable.
      class Calendar
        # Retreives events from calendar configured in the environment.
        SCOPES = [
          ::Google::Apis::CalendarV3::AUTH_CALENDAR_EVENTS_READONLY
        ].freeze
        def self.events
          credentials = SlackStatusBot::Authenticators::Google.get_or_create_credentials!(SCOPES)
          true
        end
      end
    end
  end
end
