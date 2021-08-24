require 'google/apis/calendar_v3'

module SpecHelpers
  module Integrations
    class GoogleCalendar
      extend RSpec::Mocks::ExampleMethods

      def self.create_unauthenticated_responses!
        allow(SlackStatusBot::GoogleCalendar).to receive(:start_of_week).and_return(1)
        allow(SlackStatusBot::GoogleCalendar).to receive(:end_of_week).and_return(2)
        mocked_exception = Google::Apis::AuthorizationError.new(status_code: 403,
                                                                body: 'You shall not pass!')
        allow_any_instance_of(Google::Apis::CalendarV3::CalendarService)
          .to receive(:list_events)
          .and_raise(mocked_exception)
      end
    end
  end
end
