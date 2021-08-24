# frozen_string_literal: true

module SpecHelpers
  module Utils
    class HTTP
      extend RSpec::Mocks::ExampleMethods
      def self.generate_mocked_response(body)
        double(HTTParty::Response, code: 200, body: body)
      end
    end
  end
end
