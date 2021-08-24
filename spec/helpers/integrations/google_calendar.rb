# frozen_string_literal: true

module SpecHelpers
  module Integrations
    class GoogleCalendar
      extend RSpec::Mocks::ExampleMethods
      def self.generate(endpoint, params: nil)
        TestMocks::URI.generate(ENV['MOCKED_GOOGLE_CALENDAR_API_URL'],
                                endpoint.gsub(%r{^/}, ''),
                                params: params)
      end
    end
  end
end
