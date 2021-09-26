# frozen_string_literal: true

require 'spec_helper'
require 'slack_status_bot/receivers/google/base'
require 'slack_status_bot/receivers/google/models'
require 'dynamoid'

# Handle storing and purging test creds.
class TestCredentials
  @client_id = 'fake-client-id'
  @access_token = 'fake-access-token'
  @refresh_token = 'fake-refresh-token'

  def self.create!
    SlackStatusBot.logger.debug('Creating test credentials for Google Calendar specs')
    Models::Credentials.new(client_id: @client_id,
                            access_token: @access_token,
                            refresh_token: @refresh_token).save
  end

  def self.drop!
    SlackStatusBot.logger.debug('Dropping test credentials for Google Calendar specs')
    Models::Credentials.where(client_id: @client_id).delete_all
  end
end

describe 'Given a class that performs Google API chores' do
  before(:all) do
    Base = SlackStatusBot::Receivers::Google::Base
    Models = SlackStatusBot::Receivers::Google::Models
    ENV['DYNAMODB_LOCAL'] = 'true'
    Base.init_tokens_database!
  end
  context 'When we validate our environment' do
    example 'It validates correct client JSON', :unit do
      ENV['GOOGLE_CLIENT_ID_JSON'] = File.read('spec/fixtures/fake_google_client_id.json')
      expect(Base.client_id_valid?).to be true
    end
  end

  context 'When we retrieve access and refresh tokens' do
    before(:each) { TestCredentials.create! }
    after(:each) { TestCredentials.drop! }
    example 'We can retrieve a stored token from DynamoDB', :unit do
      creds = Base.creds_for_client_id('fake-client-id')
      expect(creds.access_token).to eq 'fake-access-token'
      expect(creds.refresh_token).to eq 'fake-refresh-token'
    end
    example 'We can update a stored token when prompted', :unit do
      Base.update_creds(access_token: 'updated-access-token')
      creds = Models::Credentials.find(client_id: TestCredentials.client_id)
      expect(creds.access_token).to eq 'updated-access-token'
    end
  end
end

describe 'Given a receiver for Slack Status Bot that can retrieve statuses from Google Calendar' do
end
