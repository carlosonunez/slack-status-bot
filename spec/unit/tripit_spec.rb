require 'spec_helper'

# Because we are mocking so many HTTP responses given the number of scenarios
# that this bot must account for, the tests really check that the mocked
# HTTParty calls receive the URL that they should be receiving.
#
# These mocks are generated in spec/spec_helper.rb. Check that file out to
# see what's going on.
describe "Given a TripIt integration for Slack status bot" do
  context "When I'm not in the air" do
    context "And I'm in a business trip" do
      context "And I'm not remote" do
        example "It should show which client I'm engaged with", :unit do
          TestMocks::create_mocked_responses!(in_air: false,
                                              is_business_trip: true,
                                              remote: false)
          expect(SlackStatusBot::TripIt.update!).to be true
        end
      end

      context "And I'm remote" do
        example "It should show the client I'm engaged with and me being remote", :unit do
          TestMocks::create_mocked_responses!(in_air: false,
                                              is_business_trip: true,
                                              remote: true)
          expect(SlackStatusBot::TripIt.update!).to be true
        end
      end
    end
  end
end
