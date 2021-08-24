# frozen_string_literal: true

module SpecHelpers
  module TestMocks
    module URI
      def self.generate(base_url, endpoint, params: nil)
        uri = "#{base_url}/#{endpoint}"
        return uri + '?' + params.map { |k, v| "#{k}=#{v}" }.join('&') unless params.nil?

        uri
      end
    end
  end
end
