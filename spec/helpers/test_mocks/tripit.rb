# frozen_string_literal: true

require_relative '../test_mocks'

module SpecHelpers
  module TestMocks
    module TripIt
      def self.generate(endpoint, params: nil)
        TestMocks::URI.generate(ENV['MOCKED_TRIPIT_API_URL'],
                                endpoint.gsub(%r{^/}, ''),
                                params: params)
      end
    end
  end
end
