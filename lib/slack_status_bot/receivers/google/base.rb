# frozen_string_literal: true

require 'json'
require 'slack_status_bot/receivers/google/errors'
require 'googleauth/token_store'

module SlackStatusBot
  module Receivers
    module Google
      # This class contains functions that handle "Google API chores," such
      # as authentication and response handling.
      DynamoDB = SlackStatusBot::Receivers::Persistence::Databases::DynamoDB
      OOB_URL = 'urn:ietf:wg:oauth:2.0:oob'

      # An in-memory representation of a TokenStore
      class InMemoryTokenStore < ::Google::Auth::TokenStore
        def initialize(_options = {})
          super()
          @store ||= {}
        end

        def load(id)
          @store[id]
        end

        def store(id, token)
          @store[id] = token
        end

        def delete(id)
          @store.reject! { |k| k == id }
        end
      end

      # Base provides methods for authenticating with Google APIs.
      class Base
        include Errors

        # Generate a set of access and refresh tokens. Assume that none currently exist.
        def self.generate_tokens_or_raise!(oauth_scopes, user_id = 'default')
          token_store = InMemoryTokenStore.new
          authorizer = ::Google::Auth::UserAuthorizer.new(client_id, oauth_scopes, token_store)
          auth_url = authorizer.get_authorization_url(base_url: OOB_URL)
          $stdout.print "==> Visit this URL to complete authentication: #{auth_url}\n"
          $stdout.print '==> Then enter the code that you received here: '
          code = $stdin.gets
          begin
            credentials = authorizer.get_and_store_credentials_from_code(
              user_id: user_id,
              code: code,
              base_url: OOB_URL
            )
            {
              access_token: credentials['access_token'],
              refresh_token: credentials['refresh_token']
            }
          rescue StandardError => e
            raise "Failed to generate access and refresh tokens: #{e}"
          end
        end

        # Creates an in-memory representation of a TokenStore to avoid persisting
        # stale tokens in the filesystems.
        def self.create_local_store!
          InMemoryTokenStore.new
        end

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

        def self.client_secret
          client[:client_secret]
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
