require 'spec_helper'

describe "Given a TripIt integration for Slack status bot" do
  context "When I'm not in the air" do
    context "And I'm in a business trip" do
      example "It Should show which client I'm engaged with", :unit do
        TestMocks::create_mocked_responses!(in_air: false,
                                            is_business_trip: true)
        expect(SlackStatusBot::TripIt.update!).to be true
      end
    end
  end
end
