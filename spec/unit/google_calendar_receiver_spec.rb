# frozen_string_literal: true

require 'spec_helper'
require 'slack_status_bot/receivers/google/base'
require 'slack_status_bot/receivers/google/models'
require 'dynamoid'

describe 'Given a class that performs Google API chores' do
  before(:all) do
    Base = SlackStatusBot::Receivers::Google::Base
    Models = SlackStatusBot::Receivers::Google::Models
  end
  context 'When we validate our environment' do
    example 'It validates correct client JSON', :unit do
      ENV['GOOGLE_CLIENT_ID_JSON'] = File.read('spec/fixtures/fake_google_client_id.json')
      expect(Base.client_id_valid?).to be true
    end
  end

  context 'When we retrieve access and refresh tokens' do
    before do
      Base.setup_database!
    end
    example 'We can retrieve a stored token from DynamoDB', :unit do
      creds = Models::Credentials.new(client_id: 'fake-client-id',
                                      access_token: 'fake-access-token',
                                      refresh_token: 'fake-refresh-token')
      creds.save
      tokens = Base.existing_tokens('fake-client-id')
      expect(tokens[:access_token]).to eq 'fake-access-token'
      expect(tokens[:refresh_token]).to eq 'fake-refresh-token'
    end
  end
end

describe 'Given a receiver for Slack Status Bot that can retrieve statuses from Google Calendar' do
end
