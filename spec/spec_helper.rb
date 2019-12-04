require 'rspec'
require 'httparty'
require 'slack_status_bot'

RSpec.configure do |config|
  config.before(:each, :unit => true) do
    TestMocks.mock_emojis_file!
    $test_mocks = {
      not_in_air: {
        business: {
          flights: {},
          current_trip: 'Work: Test Client - Week n',
          current_city: 'Anywhere, US',
          status: 'Test Client @ Anywhere, US',
          emoji: ':cool:'
        },
        personal: {
          flights: {},
          current_trip: 'Personal: Doing my thang',
          current_city: 'Anywhere, US',
          status: 'Vacationing!',
          emoji: ':vacation:'
        }
      },
      in_air: {
        business: {
          flights: {
            flight_number: 'AA1',
            origin: 'JFK',
            destination: 'LAX',
            depart_time: 123456789,
            arrive_time: 234567890
          },
          current_trip: 'Work: Test Client - Week n',
          status: 'Test Client - AA1: JFK to LAX',
          current_city: 'Anywhere, US',
          emoji: ':plane:'
        },
        personal: {
          flights: {
            flight_number: 'AA1',
            origin: 'JFK',
            destination: 'LAX',
            depart_time: 123456789,
            arrive_time: 234567890
          },
          current_trip: 'Personal: Doing my thang',
          status: 'Vacationing!',
          current_city: 'Anywhere, US',
          emoji: ':vacation:'
        }
      },
    }
  end
end

module TestMocks
  extend RSpec::Mocks::ExampleMethods
  def self.mock_emojis_file!
    allow(File).to receive(:read)
      .with('./include/city_emojis.yml')
      .and_return('Anywhere, US: ":cool:"')
  end

  def self.create_mocked_responses!(in_air:, is_business_trip:)
    in_air_key = in_air ? :in_air : :not_in_air
    type_key = is_business_trip ? :business : :personal
    current_trip = $test_mocks[in_air_key][type_key][:current_trip]
    current_city = $test_mocks[in_air_key][type_key][:current_city]
    flights = $test_mocks[in_air_key][type_key][:flights]
    status = $test_mocks[in_air_key][type_key][:status]
    emoji = $test_mocks[in_air_key][type_key][:emoji]
    expected_status = status + " " + emoji
    expect(HTTParty).to receive(:get)
      .with(TestMocks::TripIt.generate('/current_trip'),
           headers: {'x-api-key': ENV['MOCKED_TRIPIT_API_KEY']})
      .and_return(self.generate_mocked_response({status: 'ok',
                   trip: {trip_name: current_trip,
                          current_city: current_city,
                          todays_flight: flights}}.to_json))
    expect(HTTParty).to receive(:post)
      .with(TestMocks::Slack.generate(
        '/status',
        params: {
          text: status,
          emoji: emoji
        }), headers: {'x-api-key': ENV['MOCKED_SLACK_API_KEY']})
      .and_return(self.generate_mocked_response({status: 'ok',
                   changed: {old: ':rocket: Old status',
                             new: expected_status}}.to_json))
  end

  module Slack
    def self.generate(endpoint, params: nil)
      TestMocks.generate_uri(ENV['MOCKED_SLACK_API_URL'],
                             endpoint.gsub(/^\//,''),
                             params: params)
    end
  end

  module TripIt
    def self.generate(endpoint, params: nil)
      TestMocks.generate_uri(ENV['MOCKED_TRIPIT_API_URL'],
                             endpoint.gsub(/^\//,''),
                             params: params)
    end
  end

  private
  def self.generate_uri(base_url, endpoint, params: nil)
    uri = base_url + '/' + endpoint
    if !params.nil?
      return uri + '?' + params.map{|k,v| "#{k}=#{v}"}.join('&')
    end
    return uri
  end

  def self.generate_mocked_response(body)
    double(HTTParty::Response, code: 200, body: body)
  end
end
