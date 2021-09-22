# frozen_string_literal: true

require 'rspec'
require 'httparty'
require 'yaml'
require 'slack_status_bot'
require_relative 'helpers/test_mocks'

RSpec.configure do |config|
  config.before(:all, unit: true) do
    SpecHelpers::Testdata.wait_for_local_dynamodb_or_fail!
  end
  config.before(:each, unit: true) do
    $test_mocks = YAML.safe_load(File.read('./spec/fixtures/test_mocks.yaml'),
                                 symbolize_names: true)
    SpecHelpers::TestMocks.mock_emojis_file!
  end
end

module SpecHelpers
  module Testdata
    def self.wait_for_local_dynamodb_or_fail!(attempts = 0)
      raise 'Failed to connect to DynamoDB' if attempts == 5

      logger = Logger.new($stdout)
      logger.level = ENV['LOG_LEVEL'] || Logger::WARN

      logger.info("Waiting up to 60 seconds for local DynamoDB to be ready at #{ENV['DYNAMODB_HOST']}:#{ENV['DYNAMODB_PORT']}")
      Socket.tcp(ENV['DYNAMODB_HOST'], ENV['DYNAMODB_PORT'], connect_timeout: 60)
    rescue StandardError => e
      if e.message.match?(/Connection refused/)
        logger.warn("Failed to connect; waiting #{attempts * attempts} seconds before next attempt...")
        sleep(attempts * attempts)
        wait_for_local_dynamodb_or_fail!(attempts + 1)
      else
        raise e
      end
    end
  end

  module TestMocks
    extend RSpec::Mocks::ExampleMethods
    def self.mock_emojis_file!
      allow(File).to receive(:read)
        .and_call_original
      allow(File).to receive(:read)
        .with(SlackStatusBot::CITY_EMOJIS_FILE)
        .and_return('Anywhere, US: ":cool:"')
    end

    def self.create_mocked_responses!(in_air:,
                                      is_business_trip:,
                                      remote: false,
                                      holiday_party: false,
                                      after_hours: false,
                                      weekend: false,
                                      mocked_time: 1_575_660_000,
                                      on_vacation: false,
                                      status_expiration_stale: true,
                                      on_beach: false)
      allow(Time).to receive(:now).and_return(Time.at(mocked_time))
      in_air_key = in_air ? :in_air : :not_in_air
      type_key = is_business_trip ? :business : :personal
      type_key = :holiday_party if holiday_party
      type_key = :vacation if on_vacation
      type_key = :beach if on_beach
      remote_key = remote ? :remote : :not_remote
      this_response = $test_mocks[in_air_key][type_key]
      this_response = this_response[remote_key] if this_response.key? remote_key
      current_trip = this_response[:current_trip]
      current_city = this_response[:current_city]
      flights = this_response[:flights]
      if weekend && !on_vacation
        status = 'Yay, weekend!'
        emoji = ':sunglasses:'
      else
        status = this_response[:status]
        emoji = this_response[:emoji]
        if after_hours
          status += ' (My work phone is off. Availability might be limited.)'
          emoji = ':sleeping:'
        end
      end
      expected_status = "#{status} #{emoji}"
      allow(SlackStatusBot::TripIt)
        .to receive(:status_expiration_stale?)
        .and_return(status_expiration_stale)
      expect(HTTParty).to receive(:get)
        .with(TestMocks::TripIt.generate('/current_trip'),
              headers: { 'x-api-key': ENV['MOCKED_TRIPIT_API_KEY'] })
        .and_return(generate_mocked_response({ status: 'ok',
                                               trip: { trip_name: current_trip,
                                                       current_city: current_city,
                                                       todays_flight: flights } }.to_json))
      expect(HTTParty).to receive(:post)
        .with(TestMocks::Slack.generate(
                '/status',
                params: {
                  text: status,
                  emoji: emoji,
                  expiration: 0
                }
              ), headers: { 'x-api-key': ENV['MOCKED_SLACK_API_KEY'] })
        .and_return(generate_mocked_response({ status: 'ok',
                                               changed: { old: ':rocket: Old status',
                                                          new: expected_status } }.to_json))
    end

    def self.generate_mocked_response(body)
      double(HTTParty::Response, code: 200, body: body)
    end
  end
end
