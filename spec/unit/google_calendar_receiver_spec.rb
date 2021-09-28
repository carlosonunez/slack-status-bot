# frozen_string_literal: true

require 'spec_helper'
require 'slack_status_bot/receivers/google/base'
require 'slack_status_bot/receivers/google/models'
require 'dynamoid'

# Handle storing and purging test creds.
class TestCredentials
  def self.client_id
    'fake-client-id'
  end

  def self.access_token
    'fake-access-token'
  end

  def self.refresh_token
    'fake-refresh-token'
  end

  def self.create!
    SlackStatusBot.logger.debug('Creating test credentials for Google Calendar specs')
    Models::Credentials.new(client_id: client_id,
                            access_token: access_token,
                            refresh_token: refresh_token).save
  end

  def self.drop!
    SlackStatusBot.logger.debug('Dropping test credentials for Google Calendar specs')
    Models::Credentials.where(client_id: client_id).delete_all
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
      expect(Base.client_valid?).to be true
    end
  end

  context 'When we retrieve access and refresh tokens' do
    before(:each) { TestCredentials.create! }
    after(:each) { TestCredentials.drop! }
    example 'We can retrieve a stored token from DynamoDB', :unit do
      allow(Base).to receive(:client_id).and_return('fake-client-id')

      expect(Base.credentials.access_token).to eq 'fake-access-token'
      expect(Base.credentials.refresh_token).to eq 'fake-refresh-token'
    end
    example 'We can update a stored access token when needed', :unit do
      allow(Base).to receive(:client_id).and_return('fake-client-id')

      Base.update_access_token!(access_token: 'updated-access-token')
      creds = Models::Credentials.find(TestCredentials.client_id)
      expect(creds.access_token).to eq 'updated-access-token'
    end
  end

  context 'When we authenticate' do
    context 'And we have not authenticated yet' do
      context 'And we have not explicitly said we want to authenticate' do
        example 'Then fail and tell the user that they need to auth', :unit do
          allow(Base).to receive(:credentials).and_return(nil)
          expect { Base.authenticate! }
            .to raise_error(<<~EXCEPTION
              You need to authenticate first. Use the \
              --authenticate-google-apis command line switch \
              to do this.
            EXCEPTION
                           )
        end
      end
      context 'And we have explicitly said we want to authenticate' do
        example 'Then initiate the offline authentication flow', :unit do
          allow(Base).to receive(:credentials).and_return(nil)
          allow(Base).to receive(:generate_tokens_or_raise!).and_return({})
          allow(Base).to receive(:persist_tokens_or_raise!).and_return(true)
          expect(Base).to receive(:generate_tokens_or_raise!)
          expect { Base.authenticate!(auth_if_creds_missing: true) }
            .not_to raise_error
        end
      end
    end
  end

  context 'When we start the authentication flow' do
    # Google's authorizer requires that the user provide a file or a Redis instance
    # to store access and refresh tokens. This is much more stateful than I'd like.
    # Furthermore, mmap2 doesn't seem to work (throws errno 22 every time I try using it)
    # and mock_redis doesn't expose a URL that Google's Redis client can use.
    #
    # Instead, we'll create a simple implementation of a `TokenStore` that stores
    # token data in a hashmap.
    example 'Then we are able to create an in-memory local store to use as a TokenStore', :unit do
      store = Base.create_local_store!
      expect(store.class).to be < Google::Auth::TokenStore

      store.store('foo', { bar: 'baaz' })
      expect(store.load('foo')[:bar]).to eq 'baaz'

      store.delete('foo')
      expect(store.load('foo')).to be nil
    end
  end
end

describe 'Given a receiver for Slack Status Bot that can retrieve statuses from Google Calendar' do
end
