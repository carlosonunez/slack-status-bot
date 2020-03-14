require_relative '../test_mocks.rb'

module SpecHelpers
  module TestMocks
    module TripIt
      def self.generate(endpoint, params: nil)
        TestMocks::URI.generate(ENV['MOCKED_TRIPIT_API_URL'],
                               endpoint.gsub(/^\//,''),
                               params: params)
      end
    end
  end
end

