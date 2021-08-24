# frozen_string_literal: true

module SpecHelpers
  module Integrations
    class TripIt
      extend RSpec::Mocks::ExampleMethods

      @test_mocks ||= YAML.safe_load(File.read('./spec/fixtures/test_mocks/tripit.yaml'),
                                     symbolize_names: true)

      def self.create_mocked_responses!(in_air:,
                                        is_business_trip:,
                                        remote: false,
                                        holiday_party: false,
                                        after_hours: false,
                                        weekend: false,
                                        mocked_time: 1_575_660_000,
                                        on_vacation: false)
        allow(Time).to receive(:now).and_return(Time.at(mocked_time))
        in_air_key = in_air ? :in_air : :not_in_air
        type_key = is_business_trip ? :business : :personal
        type_key = :holiday_party if holiday_party
        type_key = :vacation if on_vacation
        remote_key = remote ? :remote : :not_remote
        this_response = @test_mocks[in_air_key][type_key]
        this_response = this_response[remote_key] if this_response.key? remote_key
        current_trip = this_response[:current_trip]
        current_city = this_response[:current_city]
        flights = this_response[:flights]
        if weekend && !on_vacation
          status = 'Yay, weekend!'
          emoji = ':sunglasses:'
        else
          status = this_response[:status]
          status += ' (My work phone is off. Availability might be limited.)' if after_hours
          emoji = this_response[:emoji]
        end
        expected_status = "#{status} #{emoji}"
        expect(HTTParty).to receive(:get)
          .with(generate('/current_trip'),
                headers: { 'x-api-key': ENV['MOCKED_TRIPIT_API_KEY'] })
          .and_return(SpecHelpers::Utils::HTTP.generate_mocked_response(
                        { status: 'ok',
                          trip: { trip_name: current_trip,
                                  current_city: current_city,
                                  todays_flight: flights } }.to_json
                      ))
        expect(HTTParty).to receive(:post)
          .with(SpecHelpers::Receivers::Slack.generate(
                  '/status',
                  params: {
                    text: status,
                    emoji: emoji
                  }
                ), headers: { 'x-api-key': ENV['MOCKED_SLACK_API_KEY'] })
          .and_return(SpecHelpers::Utils::HTTP.generate_mocked_response(
                        { status: 'ok',
                          changed: { old: ':rocket: Old status',
                                     new: expected_status } }.to_json
                      ))
      end

      def self.generate(endpoint, params: nil)
        SpecHelpers::Utils::URI.generate(ENV['MOCKED_TRIPIT_API_URL'],
                                         endpoint.gsub(%r{^/}, ''),
                                         params: params)
      end
    end
  end
end
