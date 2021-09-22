# frozen_string_literal: true

require 'spec_helper'

describe 'Given a database initializer for DynamoDB' do
  before(:all) do
    DynamoDB = SlackStatusBot::Receivers::Persistence::Databases::DynamoDB
  end
  after(:each) do
    Dynamoid.configure do |config|
      config.namespace = nil
      config.access_key = nil
      config.secret_key = nil
      config.region = nil
      config.credentials = nil
    end
  end
  context 'When I initialize a local DynamoDB instance' do
    example 'Then it initializes', :unit do
      ENV['DYNAMODB_LOCAL'] = 'true'
      DynamoDB.start!(namespace: 'foo')
      expect(DynamoDB).not_to receive(:assumed_role_credentials)
      got = Dynamoid.config
      expect(got.namespace).to eq 'receivers-foo'
      expect(got.access_key).to be nil
      expect(got.secret_key).to be nil
      expect(got.region).to be nil
      expect(got.credentials).to be nil
    end
  end
  context 'When I initialize a local DynamoDB instance' do
    context 'And it uses a plain AK/SK credential pair' do
      context 'And none are provided' do
        example 'Then it fails to initialize', :unit do
          ENV['DYNAMODB_LOCAL'] = 'false'
          expect { DynamoDB.start!(namespace: 'foo') }.to raise_error(/Please define AWS_ACCESS_KEY_ID/)
        end
        example 'Then it initializes', :unit do
          ENV['DYNAMODB_LOCAL'] = 'false'
          ENV['AWS_ACCESS_KEY_ID'] = 'akia-its-fake'
          ENV['AWS_SECRET_ACCESS_KEY'] = 'supersecret'
          ENV['AWS_REGION'] = 'us-tirefire-1'
          DynamoDB.start!(namespace: 'foo')
          expect(DynamoDB).not_to receive(:assumed_role_credentials)
          got = Dynamoid.config
          expect(got.namespace).to eq 'receivers-foo'
          expect(got.access_key).to eq 'akia-its-fake'
          expect(got.secret_key).to eq 'supersecret'
          expect(got.region).to eq 'us-tirefire-1'
          expect(got.credentials).to be nil
        end
      end
    end
    context 'And it uses AWS STS' do
      context 'And AWS_STS_ROLE_ARN is not provided' do
        example 'Then it fails to initialize', :unit do
          ENV['DYNAMODB_LOCAL'] = 'false'
          ENV['AWS_ACCESS_KEY_ID'] = 'akia-its-fake'
          ENV['AWS_SECRET_ACCESS_KEY'] = 'supersecret'
          ENV['AWS_REGION'] = 'us-tirefire-1'
          ENV['AWS_USE_STS'] = 'true'
          expect { DynamoDB.start!(namespace: 'foo') }.to raise_error(/Please define AWS_STS_ROLE_ARN/)
        end
        example 'Then it initializes', :unit do
          ENV['AWS_ACCESS_KEY_ID'] = 'akia-its-fake'
          ENV['AWS_SECRET_ACCESS_KEY'] = 'supersecret'
          ENV['AWS_REGION'] = 'us-tirefire-1'
          ENV['AWS_STS_ROLE_ARN'] = 'my-role'
          fake_creds = { called: true }
          allow(DynamoDB).to receive(:assumed_role_credentials).and_return(fake_creds)
          DynamoDB.start!(namespace: 'foo')
          got = Dynamoid.config
          expect(got.namespace).to eq 'receivers-foo'
          expect(got.access_key).to eq nil
          expect(got.secret_key).to eq nil
          expect(got.region).to eq nil
          expect(got.credentials[:called]).to eq true
        end
      end
    end
  end
end
