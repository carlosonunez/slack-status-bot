# frozen_string_literal: true

require 'spec_helper'
require 'slack_status_bot/receivers/google/base'

describe 'Given a class that performs Google API chores' do
  example 'It validates correct client JSON', :unit do
    ENV['GOOGLE_CLIENT_ID_JSON'] = File.read('spec/fixtures/fake_google_client_id.json')
    expect(SlackStatusBot::Receivers::Google::Base.client_id_valid?).to be true
  end
end

describe 'Given a receiver for Slack Status Bot that can retrieve statuses from Google Calendar' do
end
