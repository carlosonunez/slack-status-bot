require 'spec_helper'

# Because we are mocking so many HTTP responses given the number of scenarios
# that this bot must account for, the tests really check that the mocked
# HTTParty calls receive the URL that they should be receiving.
#
# These mocks are generated in spec/spec_helper.rb. Check that file out to
# see what's going on.
describe "Given a TripIt integration for Slack status bot" do
  context "When it's the weekend" do
    example "it should show that it's the weekend after 5pm CT Friday", :unit do
      mocked_friday_afterhours = 1576278060 # Time is in UTC.
      SpecHelpers::TestMocks::create_mocked_responses!(in_air: false,
                                          is_business_trip: true,
                                          remote: false,
                                          after_hours: true,
                                          weekend: true,
                                          mocked_time: Time.at(mocked_friday_afterhours))
      expect(SlackStatusBot::TripIt.update!).to be true
    end

    example "It should show that it's the weekend", :unit do
      # Times are in UTC.
      mocked_saturday = 1575698400
      mocked_sunday = 1575784800
      [ mocked_saturday, mocked_sunday ].each do |day|
        SpecHelpers::TestMocks::create_mocked_responses!(in_air: false,
                                            is_business_trip: true,
                                            remote: false,
                                            after_hours: true,
                                            weekend: true,
                                            mocked_time: Time.at(day))
        expect(SlackStatusBot::TripIt.update!).to be true
      end
    end
  end

  context "When it's after hours" do
    example "It should show that my availability is limited", :unit do
      SpecHelpers::TestMocks::create_mocked_responses!(in_air: false,
                                          is_business_trip: true,
                                          remote: false,
                                          after_hours: true,
                                          mocked_time: 1575447225)
      expect(SlackStatusBot::TripIt.update!).to be true
    end
  end
  context "When I'm not in the air" do
    context "And I'm in a business trip" do
      context "And I'm not remote" do
        example "It should show which client I'm engaged with", :unit do
          SpecHelpers::TestMocks::create_mocked_responses!(in_air: false,
                                              is_business_trip: true,
                                              remote: false)
          expect(SlackStatusBot::TripIt.update!).to be true
        end
      end

      context "And I'm remote" do
        example "It should show the client I'm engaged with and me being remote", :unit do
          SpecHelpers::TestMocks::create_mocked_responses!(in_air: false,
                                              is_business_trip: true,
                                              remote: true)
          expect(SlackStatusBot::TripIt.update!).to be true
        end
      end
    end
    
    context "And I'm on a personal trip" do
      example "It should show that I'm not around", :unit do
          SpecHelpers::TestMocks::create_mocked_responses!(in_air: false,
                                              is_business_trip: false)
          expect(SlackStatusBot::TripIt.update!).to be true
      end
    end

    context "And I'm partying it up!" do
      example "It should show that beast mode is in progress", :unit do
          SpecHelpers::TestMocks::create_mocked_responses!(in_air: false,
                                              is_business_trip: false,
                                              holiday_party: true)
          expect(SlackStatusBot::TripIt.update!).to be true
      end
    end

    context "And I'm on vacation" do
      example "It should show that I'm out of office", :unit do
          SpecHelpers::TestMocks::create_mocked_responses!(in_air: false,
                                              is_business_trip: false,
                                              holiday_party: false,
                                              on_vacation: true)
          expect(SlackStatusBot::TripIt.update!).to be true
      end
    end
  end

  context "When I'm in the air" do
    context "And I'm in a business trip" do
      example "It should show my flight info along with my current client", :unit do
        SpecHelpers::TestMocks::create_mocked_responses!(in_air: true,
                                            is_business_trip: true)
        expect(SlackStatusBot::TripIt.update!).to be true
      end
    end
    
    context "And I'm on a personal trip" do
      example "It should show that I'm not around", :unit do
          SpecHelpers::TestMocks::create_mocked_responses!(in_air: true,
                                              is_business_trip: false)
          expect(SlackStatusBot::TripIt.update!).to be true
      end
    end

    context "And I'm about to get absolutely shitty!" do
      example "It should show that beast mode is in flight", :unit do
          SpecHelpers::TestMocks::create_mocked_responses!(in_air: true,
                                              is_business_trip: false,
                                              holiday_party: true)
          expect(SlackStatusBot::TripIt.update!).to be true
      end
    end
    context "And I'm on vacation" do
      example "It should show that I'm out of office", :unit do
          SpecHelpers::TestMocks::create_mocked_responses!(in_air: true,
                                              is_business_trip: false,
                                              holiday_party: false,
                                              on_vacation: true)
          expect(SlackStatusBot::TripIt.update!).to be true
      end
    end
  end
end
