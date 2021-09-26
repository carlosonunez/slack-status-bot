# frozen_string_literal: true

require 'dynamoid'

module SlackStatusBot
  module Receivers
    module Persistence
      module Databases
        # A quick and dirty client wrapper for DynamoDB.
        class DynamoDB
          extend SlackStatusBot::Logging

          # NOTE: DynamoDB creds must be consistent
          #
          # Because DynamoDB tables are segmented by account and because we are dropping
          # tables whenever we start our test suite, we need to make sure that our
          # spec_helper has the same credentials as that used by whatever class
          # uses this to initialize a DynamoDB database.
          LOCAL_CREDENTIALS = {
            access_key: 'fake-key',
            secret_key: 'supersecret',
            region: 'us-tirefire-1'
          }.freeze

          def self.start!(namespace:)
            Dynamoid.configure do |config|
              config.namespace = "receivers-#{namespace}"
              if local?
                logger.debug("DynamoDB namespace => #{config.namespace}, \
local host: #{ENV['DYNAMODB_HOST']}, port: #{ENV['DYNAMODB_PORT']}")
                config.endpoint = "http://#{ENV['DYNAMODB_HOST']}:#{ENV['DYNAMODB_PORT']}"
                config.access_key = LOCAL_CREDENTIALS[:access_key]
                config.secret_key = LOCAL_CREDENTIALS[:secret_key]
                config.region = LOCAL_CREDENTIALS[:region]
              else
                config.region = aws_credentials[:region]
                if aws_credentials[:is_sts_token]
                  config.credentials = aws_credentials[:assumed_creds]
                else
                  config.access_key = aws_credentials[:access_key_id]
                  config.secret_key = aws_credentials[:secret_access_key]
                end
              end
            end
          end

          def self.local?
            (ENV['DYNAMODB_LOCAL'] || '').downcase == 'true'
          end

          def self.aws_credentials
            %w[AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_REGION].each do |var|
              raise "Please define #{var}" if ENV[var].nil?
            end
            config = {}
            if (ENV['AWS_USE_STS'] || '').downcase == 'true'
              raise 'Please define AWS_STS_ROLE_ARN' if ENV['AWS_STS_ROLE_ARN'].nil?

              logger.debug('Using AWS STS for DynamoDB credentials')
              config[:is_sts_token] = true
              config[:assumed_creds] = assumed_role_credentials
            else
              logger.debug('Using AWS programmatic access for DynamoDB credentials')
              config[:is_sts_token] = false
              config[:access_key_id] = ENV['AWS_ACCESS_KEY_ID']
              config[:secret_access_key] = ENV['AWS_SECRET_ACCESS_KEY']
              config[:region] = ENV['AWS_REGION']
            end
            config
          end

          def self.assumed_role_credentials
            Aws::AssumeRoleCredentials.new(
              region: ENV['AWS_REGION'],
              access_key_id: ENV['AWS_ACCESS_KEY_ID'],
              secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
              role_arn: ENV['AWS_STS_ROLE_ARN'],
              role_session_name: "status-receiver-session-#{Time.now.strftime('%s')}",
              external_id: ENV['AWS_STS_EXTERNAL_ID'] || ''
            )
          end
        end
      end
    end
  end
end
