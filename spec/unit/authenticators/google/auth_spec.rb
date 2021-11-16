# frozen_string_literal: true

require 'spec_helper'
require 'slack_status_bot/authenticators/google'
require 'slack_status_bot/models/google/credentials'
require 'dynamoid'
require 'googleauth'

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
    Credentials.new(client_id: client_id,
                    access_token: access_token,
                    refresh_token: refresh_token).save
  end

  def self.drop!
    SlackStatusBot.logger.debug('Dropping test credentials for Google Calendar specs')
    Credentials.where(client_id: client_id).delete_all
  end
end

describe 'Given a helper class that retrieves or generates Google OAuth tokens' do
  before(:all) do
    ENV['DYNAMODB_LOCAL'] = 'true'
    GoogleAuthenticator = SlackStatusBot::Authenticators::Google
    Credentials = SlackStatusBot::Models::Google::Credentials
    GoogleAuthenticator.initialize_persistence!
  end
  context 'When we validate our environment' do
    example 'It validates correct client JSON', :unit do
      ENV['GOOGLE_CLIENT_ID_JSON'] = File.read('spec/fixtures/fake_google_client_id.json')
      expect(GoogleAuthenticator.client_valid?).to be true
    end
  end

  context 'When we retrieve access and refresh tokens' do
    before(:each) { TestCredentials.create! }
    after(:each) { TestCredentials.drop! }
    example 'We can retrieve a stored token from DynamoDB', :unit do
      allow(GoogleAuthenticator).to receive(:client_id).and_return('fake-client-id')

      expect(GoogleAuthenticator.credentials.access_token).to eq 'fake-access-token'
      expect(GoogleAuthenticator.credentials.refresh_token).to eq 'fake-refresh-token'
    end
  end

  context 'When a client asks for a new set of tokens' do
    example 'Then we receive tokens upon providing a code from a URL', :unit do
      fauxthorizer = double(Google::Auth::UserAuthorizer,
                            get_credentials: nil,
                            get_authorization_url: 'https://example.net/12345',
                            get_and_store_credentials_from_code: {
                              'access_token': 'fake-token',
                              'refresh_token': 'fake-refresh'
                            }.transform_keys(&:to_s))
      allow(Google::Auth::UserAuthorizer)
        .to receive(:new)
        .and_return(fauxthorizer)
      allow(GoogleAuthenticator)
        .to receive(:credentials)
        .and_return(TestCredentials)
      allow($stdin).to receive(:gets).and_return('12345')
      expected = <<~MESSAGE
        ==> Visit this URL to complete authentication: https://example.net/12345
        ==> Then enter the code that you received here:#{' '}
      MESSAGE
      expect { GoogleAuthenticator.authenticate!(oauth_scopes: 'fake-scope') }
        .to output(expected.chop)
        .to_stdout
      creds = GoogleAuthenticator.authenticate!(oauth_scopes: 'fake-scope')
      expect(creds.access_token).to eq 'fake-token'
      expect(creds.refresh_token).to eq 'fake-refresh'
    end
  end

  context 'When we attempt to authenticate an OAuth client' do
    context 'And this client does not have any pre-existing credentials' do
      before do
        allow(GoogleAuthenticator).to receive(:credentials).and_return(nil)
      end
      context 'And we have not explicitly said we want to authenticate' do
        example 'Then fail and tell the user that they need to auth', :unit do
          expect { GoogleAuthenticator.authenticate!(oauth_scopes: nil) }
            .to raise_error(<<~EXCEPTION
              You need to authenticate first. Use the \
              --authenticate-google-apis command line switch \
              to do this.
            EXCEPTION
                           )
        end
      end
      context 'And we have explicitly said we want to authenticate' do
        example 'Then the offline authentication flow should begin', :unit do
          allow(GoogleAuthenticator)
            .to receive(:generate_tokens_or_raise!)
            .with('fake-scopes', 'default')
            .and_return({})
          expect do
            GoogleAuthenticator.authenticate!(oauth_scopes: 'fake-scopes',
                                              auth_if_creds_missing: true)
          end
            .not_to raise_error
        end
      end
    end
  end
end
