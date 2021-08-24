# frozen_string_literal: true

module SpecHelpers
  module Receivers
    class Slack
      def self.generate(endpoint, params: nil)
        SpecHelpers::Utils::URI.generate(ENV['MOCKED_SLACK_API_URL'],
                                         endpoint.gsub(%r{^/}, ''),
                                         params: params)
      end
    end
  end
end
