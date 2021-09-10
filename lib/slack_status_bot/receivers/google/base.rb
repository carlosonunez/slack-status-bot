# frozen_string_literal: true

require 'json'

module SlackStatusBot
  module Receivers
    module Google
      # This class contains functions that handle "Google API chores," such
      # as authentication and response handling.
      class Base
        def self.environment_configured?
          %w[GOOGLE_APPLICATION_NAME GOOGLE_CLIENT_ID_JSON].each do |env_var|
            raise "Please define #{env_var}" if ENV[env_var].nil? || ENV[env_var].empty?
          end
        end

        def self.client_id_valid?
          app_name = ENV['GOOGLE_APPLICATION_NAME']
          client = JSON.parse(ENV['GOOGLE_CLIENT_ID_JSON'],
                              symbolize_names: true)
          return false unless client.key?(:installed)

          %w[client_id project_id client_secret].each do |required_key|
            key_present = client[:installed].key?(required_key.to_sym)
            SlackStatusBot.logger.debug("Google: #{app_name} has #{required_key}? #{key_present}")
            return false unless key_present
          end

          true
        end
      end
    end
  end
end