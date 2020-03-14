require_relative '../test_mocks.rb'

module SpecHelpers
  module TestMocks
    module Slack
        def self.generate(endpoint, params: nil)
          TestMocks::URI.generate(ENV['MOCKED_SLACK_API_URL'],
                                 endpoint.gsub(/^\//,''),
                                 params: params)
        end
    end
  end
end
