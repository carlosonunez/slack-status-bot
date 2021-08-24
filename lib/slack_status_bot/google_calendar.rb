# frozen_string_literal: true

require 'google/apis/calendar_v3'

module SlackStatusBot
  # The Google Calendar Integration creates statuses based on events in Google Calendar.
  # It matches on events based on title assuming that it matches a corresponding
  # regex in the travel_statuses file or if the event is marked as "Busy".
  # "Free" and "Tentative" events are ignored.
  class GoogleCalendar
    @calendar_id = ENV['GOOGLE_CALENDAR_ID']
    @service = nil

    def self.update!
      @service ||= create_service_instance
      events = todays_events_or_raise!
      true
    end

    def self.create_service_instance
      service = Google::Apis::CalendarV3::CalendarService.new
      service.client_options.application_name = ENV['GOOGLE_CALENDAR_OAUTH_APPLICATION_NAME']
      service.authorization = authorize
      service
    end

    def self.authorize
      # TODO: Create the authorizer.
      # Since we're using to use two-legged OAuth to do this, we will need to
      # handle storing the access and refresh token and using the refresh token
      # to create new access tokens. It is recommended to store these
      # in DynamoDB, which will require creating a new IAM role and a new IAM user
      # that can assume the role.
      nil
    end

    def self.todays_events_or_raise!
      @service.list_events(@calendar_id,
                           max_results: 100,
                           order_by: 'startTime',
                           time_min: start_of_week,
                           time_max: end_of_week)
    rescue Google::Apis::AuthorizationError => e
      show_authorization_instructions_and_throw!(e)
    rescue StandardError => e
      raise e
    end

    def self.show_authorization_instructions_and_throw!(_exn)
      message = <<~MESSAGE
        You'll need to authorize the Google Calendar integration before you can use it.
        Because this app is meant to run non-interactively, we are going to fail early.

        To do this, run this application again, but set the 'AUTHORIZE' environment
        variable to 'true'.
      MESSAGE
      raise StandardError, message
    end

    def self.start_of_week
      # TODO: Implement
      1
    end

    def self.end_of_week
      # TODO: Implement
      2
    end
  end
end
