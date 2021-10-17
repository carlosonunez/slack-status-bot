# frozen_string_literal: true

require 'spec_helper'
require 'google/apis/calendar_v3'
require 'slack_status_bot/authenticators/google'

# Creates a fake list of calendars as represented by CalendarList and
# CalendarListEntry.
def create_fake_cal_list(cal_name_id_map)
  calendar_entries = cal_name_id_map.map do |name, id|
    Google::Apis::CalendarV3::CalendarListEntry.new(id: id,
                                                    summary: name)
  end
  Google::Apis::CalendarV3::CalendarList.new(items: calendar_entries)
end

# rubocop:disable Metrics/BlockLength
describe 'Given a status receiver for Google Calendar' do
  context 'When the name of a calendar is provided in the environment' do
    before do
      @scopes = [Google::Apis::CalendarV3::AUTH_CALENDAR_EVENTS_READONLY]
      Calendar ||= SlackStatusBot::Receivers::Google::Calendar
      @creds = {
        access_token: 'fake',
        refresh_token: 'fake'
      }
    end
    context 'And our environment is not configured' do
      example 'Then a failure is raised', :unit do
        expect { Calendar.new }
          .to raise_error('GOOGLE_CALENDAR_NAME is not defined in your environment')
      end
    end
    context 'And our environment is configured' do
      before do
        ENV['GOOGLE_CALENDAR_NAME'] = 'fake-calendar'
        @fake_calendars = {
          'fake-calendar': 'fake-id',
          'fake-calendar-2': 'fake-id-we-dont-want',
          'fake-calendar-3': 'fake-id-we-dont-want'
        }.transform_keys(&:to_s)
        allow(Google::Apis::CalendarV3::CalendarService)
          .to receive(:new)
          .and_return(double(Google::Apis::CalendarV3::CalendarService,
                             :authorization= => @creds,
                             :list_calendar_lists => create_fake_cal_list(@fake_calendars)))
      end
      after do
        ENV['GOOGLE_CALENDAR_NAME'] = nil
      end
      context 'And the calendar name matches a real calendar' do
        example 'Then the matching Calendar object can be retrieved', :unit do
          allow(SlackStatusBot::Authenticators::Google)
            .to receive(:get_or_create_credentials!)
            .and_return(@creds)
          calendar = Calendar.new
          expect(calendar.id).to eq 'fake-id'
        end
      end
      context 'And the calendar name does not match a real calendar' do
        example 'Then the matching Calendar object is not retrieved', :unit do
          ENV['GOOGLE_CALENDAR_NAME'] = 'invalid-name'
          allow(SlackStatusBot::Authenticators::Google)
            .to receive(:get_or_create_credentials!)
            .and_return(@creds)
          calendar = Calendar.new
          expect(calendar.id).to be_nil
        end
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
