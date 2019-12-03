require 'rspec'
require 'httparty'

RSpec.configure do |config|
  config.before(:all, :unit => true) do
    $test_mocks = {
      not_in_air: {
        business: {
          flights: {},
          current_trip: 'Work: Test Client - Week n',
          expected_status: ':cool: Test Client @ Home'
        },
        personal: {
          flights: {},
          current_trip: 'Personal: Doing my thang',
          expected_status: ':vacation: Vacationing!'
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
          expected_status: ':plane: Test Client - AA1 - JFK to LAX'
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
          expected_status: ':vacation: Vacationing!'
        }
      },
    }
  end
end

module TestURI
  def create_mocked_responses!(in_air:, is_business_trip:)
    in_air_key = in_air ? :in_air : :not_in_air
    type_key = is_business_trip ? :business : :personal
    expect(HTTParty).to receive(:get)
      .with(TestURI::TripIt.generate('/current_trip'),
           headers: {'x-api-key': 'test-key'})
      .and_return({status: 'ok',
                   trip: {trip_name: $test_mocks[in_air_key][type_key][:trip_name],
                          todays_flight: $test_mocks[in_air_key][type_key][:flights]}}).to_json
    expect(HTTParty).to receive(:post)
      .with(TestURI::Slack.generate(
        '/status',
        params: {
          text: $test_mocks[in_air_key][type_key][:status],
          emoji: $test_mocks[in_air_key][type_key][:emoji]
        }))
      .and_return({status: 'ok',
                   changed: {old: ':rocket: Old status',
                             new: [
                               $test_mocks[in_air_key][type_key][:status],
                               $test_mocks[in_air_key][type_key][:emoji]
                             ].join(' ')}}.to_json)
  end

  module Slack
    def self.generate(endpoint, query_params: nil)
      generate_uri('https://slack.apis.carlosnunez.me',
                   endpoint,
                   query_params: query_params)
    end
  end

  module TripIt
    def self.generate(endpoint, query_params: nil)
      generate_uri('https://tripit.apis.carlosnunez.me',
                   endpoint,
                   query_params: query_params)
    end
  end

  private
  def self.generate_uri(base_url, endpoint, query_params: nil)
    uri = base_url + '/' + endpoint
    if !query_params.nil?
      return uri + '?' + query_params.map{|k,v| "#{k}=#{v}"}.join('&')
    end
    return uri
  end
end
