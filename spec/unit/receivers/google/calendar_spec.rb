# frozen_string_literal: true

require 'spec_helper'
require 'google/apis/calendar_v3'
require 'slack_status_bot/authenticators/google'

# rubocop:disable Metrics/BlockLength
describe 'Given a status receiver for Google Calendar' do
  context 'When the name of a calendar is provided in the environment' do
    before do
      @scopes = [Google::Apis::CalendarV3::AUTH_CALENDAR_EVENTS_READONLY]
      # rubocop:disable Lint/ConstantDefinitionInBlock
      Calendar = SlackStatusBot::Receivers::Google::Calendar
      # rubocop:enable Lint/ConstantDefinitionInBlock
    end
    context 'And our environment is not configured' do
      example 'Then the matching Calendar object is not retrieved', :unit do
        expect { Calendar.resolve_from_env }
          .to output(/GOOGLE_CALENDAR_NAME is not defined/)
          .to_stdout_from_any_process
        expect(Calendar.resolve_from_env).to be_nil
      end
    end
    context 'And our environment is configured' do
      before do
        ENV['GOOGLE_CALENDAR_NAME'] = 'fake-calendar'
      end
      after do
        ENV['GOOGLE_CALENDAR_NAME'] = nil
      end
      context 'And the calendar name matches a real calendar' do
        example 'Then the matching Calendar object can be retrieved', :unit do
          allow(SlackStatusBot::Authenticators::Google)
            .to receive(:get_or_create_credentials!)
            .and_return({ access_token: 'fake', refresh_token: 'fake' })
          calendar = Calendar.resolve_from_env
          expect(calendar.id).to be 'fake-id'
        end
      end
      context 'And the calendar name does not match a real calendar' do
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
