# frozen_string_literal: true

require 'spec_helper'
require 'google/apis/calendar_v3'
require 'slack_status_bot/authenticators/google'

describe 'Given a status receiver for Google Calendar' do
  context 'When we are not authenticated' do
    example 'Then we authenticate first', :unit do
      expected_scopes = [
        Google::Apis::CalendarV3::AUTH_CALENDAR_EVENTS_READONLY
      ]
      allow(SlackStatusBot::Authenticators::Google)
        .to receive(:credentials)
        .and_return(nil)
      allow(SlackStatusBot::Authenticators::Google)
        .to receive(:generate_tokens_or_raise!)
        .and_return({})
      expect(SlackStatusBot::Authenticators::Google)
        .to receive(:generate_tokens_or_raise!)
        .with(expected_scopes, 'default').once
      _ = SlackStatusBot::Receivers::Google::Calendar.events
    end
  end
end
