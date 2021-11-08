# frozen_string_literal: true

require 'spec_helper'
require 'chronic'
require 'chronic_duration'
require 'securerandom'
require 'google/apis/calendar_v3'
require 'slack_status_bot/authenticators/google'

# A convenience class for creating unnamed fake events.
# Needed because the Google APIs have their own DateTime format
class FakeEvent
  attr_accessor :start_date, :end_date, :all_day, :name

  def initialize(name:, start_date:, duration:, all_day: false)
    @start_date = parse_date(start_date)
    @end_date = calculate_end_date(start_date, duration)
    @all_day = all_day
    @name = name
  end

  def all_day?
    @all_day
  end

  # Calculates the end date of an event from a start date and duration
  def calculate_end_date(date, duration)
    parsed = parse_date(date)
    parsed_duration = ChronicDuration.parse(duration)
    parsed + parsed_duration
  end

  # Parses a human-readable date into a machine-readable date
  def parse_date(date)
    Chronic.parse(date)
  end
end

# Creates a fake list of calendars as represented by CalendarList and
# CalendarListEntry.
def create_fake_cal_list(cal_name_id_map)
  calendar_entries = cal_name_id_map.map do |name, id|
    Google::Apis::CalendarV3::CalendarListEntry.new(id: id,
                                                    summary: name)
  end
  Google::Apis::CalendarV3::CalendarList.new(items: calendar_entries)
end

# Creates a fake EventDateTime based on whether the event from which this date
# was created is an all-day event or not.
# Hardcoded to Central Time.
# See also: https://googleapis.dev/ruby/google-api-client/latest/Google/Apis/CalendarV3/EventDateTime.html
def create_fake_google_dt(dt, all_day)
  g_dt = Google::Apis::CalendarV3::EventDateTime.new(
    time_zone: 'America/Chicago',
    date_time: dt.rfc3339
  )
  g_dt.date = Date.parse(dt.to_s) if all_day
  g_dt
end

# Creates a fake set of events from a list of FakeEvents.
# See also: https://googleapis.dev/ruby/google-api-client/latest/Google/Apis/CalendarV3/Event.html#end-instance_method
def create_fake_events(events)
  events.map do |event|
    Google::Apis::CalendarV3::Event.new(
      id: SecureRandom.hex(12),
      summary: event.name,
      start: create_fake_google_dt(event.start_date, event.all_day),
      end: create_fake_google_dt(event.end_date, event.all_day)
    )
  end
end

# rubocop:disable Metrics/BlockLength
describe 'Given a status receiver for Google Calendar' do
  before do
    Calendar ||= SlackStatusBot::Receivers::Google::Calendar
  end
  context 'When we resolve the name of the calendar' do
    context 'And our environment is not configured' do
      example 'Then a failure is raised', :unit do
        ENV['GOOGLE_CALENDAR_NAME'] = nil
        expect { Calendar.new.name }
          .to raise_error('GOOGLE_CALENDAR_NAME is not defined in your environment')
      end
    end

    context 'And our environment is configured' do
      example 'Then the name of our calendar is resolved', :unit do
        ENV['GOOGLE_CALENDAR_NAME'] = 'fake-calendar'
        expect(Calendar.new.name).to eq 'fake-calendar'
      end
    end
  end

  context 'When we have a valid calendar' do
    before do
      allow(Google::Apis::CalendarV3::CalendarService)
        .to receive(:new)
        .and_return(double(Google::Apis::CalendarV3::CalendarService,
                           list_calendar_lists: {
                             'valid-calendar': 'fake-id',
                             'invalid-calendar-2': 'fake-id-we-dont-want',
                             'invalid-calendar-3': 'fake-id-we-dont-want'
                           }.transform_keys(&:to_s)))
      @calendar = double(Calendar)
    end
    context 'And the calendar name matches a calendar in our Google account' do
      example 'Then we get the ID for that calendar', :unit do
        allow(@calendar).to receive(:name).and_return('valid-calendar')
        allow(@calendar).to receive(:id).and_call_original
        expect(@calendar.id).to eq 'fake-id'
      end
    end
    context 'And the calendar name does not match a real calendar' do
      example 'Then the matching Calendar object is not retrieved', :unit do
        allow(@calendar).to receive(:name).and_return('missing-calendar')
        expect(@calendar.id).to be_nil
      end
    end
  end
  context 'When we look for events in a calendar' do
    before do
      allow(SlackStatusBot::Authenticators::Google)
        .to receive(:get_or_create_credentials!)
        .and_return(@creds)
    end
    example 'Then we can get a summarized set of them', :unit do
      ENV['GOOGLE_CALENDAR_NAME'] = 'fake-calendar'
      @events = create_fake_events([
                                     FakeEvent.new(name: 'regular-event-1',
                                                   start_date: '2021/10/30 10:00',
                                                   duration: '30 minutes'),
                                     FakeEvent.new(name: 'regular-event-2',
                                                   start_date: '2021/10/30 14:30',
                                                   duration: '20 minutes'),
                                     FakeEvent.new(name: 'all-day-event-1',
                                                   start_date: '2021/10/30 10:00',
                                                   duration: '30 minutes')
                                   ])
      allow(Google::Apis::CalendarV3::CalendarService)
        .to receive(:new)
        .and_return(double(Google::Apis::CalendarV3::CalendarService,
                           :authorization= => @creds,
                           :list_events => @events))
      expected = @events.map do |gcal_event|
        all_day = false if gcal_event.start.date.nil? &&
                           gcal_event.end.date.nil?
        {
          name: gcal_event.summary,
          start: gcal_event.start,
          end: gcal_event.end,
          all_day: all_day
        }
      end
      calendar = Calendar.new
      allow(calendar).to receive(:resolve_id).and_return('fake_id')
      expect(JSON.parse(calendar.events)).to eq(JSON.parse(expected))
    end
  end
end
# rubocop:enable Metrics/BlockLength
