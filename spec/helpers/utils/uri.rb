# frozen_string_literal: true

module SpecHelpers
  module Utils
    module URI
      def self.generate(base_url, endpoint, params: nil)
        params_str = params.map { |k, v| "#{k}=#{v}" }.join('&') unless params.nil?
        if params.nil?
          "#{base_url}/#{endpoint}"
        else
          "#{base_url}/#{endpoint}?#{params_str}"
        end
      end
    end
  end
end
