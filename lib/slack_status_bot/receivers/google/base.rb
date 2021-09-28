# frozen_string_literal: true

require 'json'
require 'slack_status_bot/receivers/google/errors'

module SlackStatusBot
  module Receivers
    module Google
      # This class contains functions that handle "Google API chores," such
      # as authentication and response handling.
      DynamoDB = SlackStatusBot::Receivers::Persistence::Databases::DynamoDB

      class Base
        include Errors

        # Attempts to obtain access and refresh tokens using offline three-legged OAuth.
        # NOTE: We are assuming that a OAuth client is used. Service accounts are not supported.
        def self.authenticate!(auth_if_creds_missing: false)
          raise ClientInvalid unless client_valid?
          raise NotAuthenticated if credentials.nil? && !auth_if_creds_missing

          tokens = generate_tokens_or_raise!
          persist_tokens_or_raise!(tokens)
        end

        def self.environment_configured?
          %w[GOOGLE_APPLICATION_NAME GOOGLE_CLIENT_ID_JSON].each do |env_var|
            raise "Please define #{env_var}" if ENV[env_var].nil? || ENV[env_var].empty?
          end
        end

        # Creates a database to associate client IDs with access/refresh tokens.
        def self.init_tokens_database!
          DynamoDB.start!(namespace: 'google_access_and_refresh_tokens')
        end

        # Reads a Google API client from the environment.
        def self.client
          JSON.parse(ENV['GOOGLE_CLIENT_ID_JSON'], symbolize_names: true)
        end

        def self.client_id
          client[:client_id]
        end

        # Tests a Google API client to ensure that required metadata is present.
        def self.client_valid?
          app_name = ENV['GOOGLE_APPLICATION_NAME']
          return false unless client.key?(:installed)

          %w[client_id project_id client_secret].each do |required_key|
            key_present = client[:installed].key?(required_key.to_sym)
            SlackStatusBot.logger.debug("Google: #{app_name} has #{required_key}? #{key_present}")
            return false unless key_present
          end

          true
        end

        def self.credentials
          Models::Credentials.find(client_id)
        end

        # Updates an access token
        # TODO: Create a workflow for updating and clearing refresh tokens.
        def self.update_access_token!(access_token:)
          Models::Credentials.find(client_id).update_attribute(:access_token, access_token)
        end
      end
    end
  end
end
