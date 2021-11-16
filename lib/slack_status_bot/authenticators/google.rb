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
      GOOGLE_AUTHENTICATOR_TABLE_PREFIX = 'google_access_and_refresh_tokens'
      REQUIRED_ENV_VARS = %w[GOOGLE_APPLICATION_NAME GOOGLE_CLIENT_ID_JSON].freeze

      # Base provides methods for authenticating with Google APIs.
      include Errors

      # Attempts to obtain access and refresh tokens using offline three-legged OAuth.
      # NOTE: We are assuming that a OAuth client is used. Service accounts are not supported.
      def self.authenticate!(oauth_scopes:, user_id: 'default', auth_if_creds_missing: false)
        raise Errors::Google::Authentication::EnvironmentInvalid unless environment_valid?
        raise Errors::Google::Authentication::ClientInvalid unless client_valid?
        raise Errors::Google::Authentication::NotAuthenticated if credentials.nil? && !auth_if_creds_missing

        generate_tokens_or_raise!(oauth_scopes, user_id)
      end

      def self.credentials
        Models::Google::Credentials.find(client_id)
      end

      # Tests a Google API client to ensure that required metadata is present.
      def self.client_valid?
        return false unless client.key?(:installed)

        %w[client_id project_id client_secret].each do |required_key|
          key_present = client[:installed].key?(required_key.to_sym)
          SlackStatusBot.logger.debug("Google: #{ENV['GOOGLE_APPLICATION_NAME']} has #{required_key}? #{key_present}")
          return false unless key_present
        end

        true
      end

      # Generate a set of access and refresh tokens. Assume that none currently exist.
      def self.generate_tokens_or_raise!(oauth_scopes, user_id = 'default')
        initialize_persistence! or raise 'Unable to initialize token database for Google authentication'
        authorizer = create_authorizer!(scopes: oauth_scopes)
        code = retrieve_code_from_stdin!(authorizer: authorizer)
        complete_auth_from_code_or_raise!(authorizer: authorizer, user_id: user_id, code: code)
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

      def self.environment_valid?
        REQUIRED_ENV_VARS.select { |var| ENV[var].empty? }.length.zero?
      end

      def self.initialize_persistence!
        DynamoDB.start!(namespace: GOOGLE_AUTHENTICATOR_TABLE_PREFIX)
      end

      def self.create_authorizer!(scopes: oauth_scopes)
        token_store = SlackStatusBot::Models::Google::InMemoryTokenStore.new
        ::Google::Auth::UserAuthorizer.new(client_id, scopes, token_store)
      end

      def self.retrieve_code_from_stdin!(authorizer:)
        auth_url = authorizer.get_authorization_url(base_url: OOB_URL)
        $stdout.print "==> Visit this URL to complete authentication: #{auth_url}\n"
        $stdout.print '==> Then enter the code that you received here: '
        $stdin.gets
      end

      def self.complete_auth_from_code_or_raise!(authorizer:, user_id:, code:)
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
  end
end
