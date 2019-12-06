require 'rspec'
require 'httparty'
require 'yaml'
require 'slack_status_bot'

RSpec.configure do |config|
  config.before(:each, :unit => true) do
    $test_mocks = YAML.load(File.read('./spec/fixtures/test_mocks.yaml'),
                            symbolize_names: true)
    TestMocks.mock_emojis_file!
  end
end

module TestMocks
  extend RSpec::Mocks::ExampleMethods
  def self.mock_emojis_file!
    allow(File).to receive(:read)
      .with('./include/city_emojis.yml')
      .and_return('Anywhere, US: ":cool:"')
  end

  def self.create_mocked_responses!(in_air:, 
                                    is_business_trip:,
                                    remote: false,
                                    holiday_party: false,
                                    after_hours: false,
                                    mocked_time: 1575660000)
    allow(Time).to receive(:now).and_return(Time.at(mocked_time))
    in_air_key = in_air ? :in_air : :not_in_air
    type_key = is_business_trip ? :business : :personal
    if holiday_party
      type_key = :holiday_party
    end
    remote_key = remote ? :remote : :not_remote
    this_response = $test_mocks[in_air_key][type_key]
    if this_response.has_key? remote_key
      this_response = this_response[remote_key]
    end
    current_trip = this_response[:current_trip]
    current_city = this_response[:current_city]
    flights = this_response[:flights]
    status = this_response[:status]
    if after_hours
      status = status + " (My work phone is off. Availability might be limited.)"
    end
    emoji = this_response[:emoji]
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
