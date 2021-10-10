# frozen_string_literal: true

require 'json'
require 'slack_status_bot/errors/google/authentication'
require 'slack_status_bot/models/google/in_memory_token_store'
require 'slack_status_bot/persistence/databases/dynamodb'

module SlackStatusBot
  module Authenticators
    # This class contains functions that handle "Google API chores," such
    # as authentication and response handling.
    class Google
      DynamoDB = SlackStatusBot::Persistence::Databases::DynamoDB
      OOB_URL = 'urn:ietf:wg:oauth:2.0:oob'

      # Base provides methods for authenticating with Google APIs.
      include Errors

      # Generate a set of access and refresh tokens. Assume that none currently exist.
      def self.generate_tokens_or_raise!(oauth_scopes, user_id = 'default')
        token_store = SlackStatusBot::Models::Google::InMemoryTokenStore.new
        authorizer = ::Google::Auth::UserAuthorizer.new(client_id, oauth_scopes, token_store)
        auth_url = authorizer.get_authorization_url(base_url: OOB_URL)
        $stdout.print "==> Visit this URL to complete authentication: #{auth_url}\n"
        $stdout.print '==> Then enter the code that you received here: '
        code = $stdin.gets
        begin
          tokens = authorizer.get_and_store_credentials_from_code(
            user_id: user_id,
            code: code,
            base_url: OOB_URL
          )
          credentials = Models::Google::Credentials.new(
            client_id: client_id,
            access_token: tokens['access_token'],
            refresh_token: tokens['refresh_token']
          )
          credentials.save
          credentials
        rescue StandardError => e
          raise "Failed to generate access and refresh tokens: #{e}"
        end
      end

      # Creates an in-memory representation of a TokenStore to avoid persisting
      # stale tokens in the filesystems.
      def self.create_local_store!
        Models::Google::InMemoryTokenStore.new
      end

      # Attempts to obtain access and refresh tokens using offline three-legged OAuth.
      # NOTE: We are assuming that a OAuth client is used. Service accounts are not supported.
      def self.authenticate!(auth_if_creds_missing: false)
        raise Errors::Google::Authentication::ClientInvalid unless client_valid?
        raise Errors::Google::Authentication::NotAuthenticated if credentials.nil? && !auth_if_creds_missing

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

      # Retrieve existing credentials or generate new credentials if none found.
      def self.get_or_create_credentials!(scopes, user_id = 'default')
        return credentials unless credentials.nil? || credentials.empty?

        generate_tokens_or_raise!(scopes, user_id)
      end

      def self.credentials
        Models::Google::Credentials.find(client_id)
      end

      # Updates an access token
      # TODO: Create a workflow for updating and clearing refresh tokens.
      def self.update_access_token!(access_token:)
        credentials.update_attribute(:access_token, access_token)
      end
    end
  end
end
