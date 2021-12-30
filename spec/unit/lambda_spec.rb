# frozen_string_literal: true

require 'spec_helper'

describe 'Given a function that determines the expiration time to set on a status' do
  example 'It adds seconds to current time if parsed time is earlier than 1_000_000_000 seconds' do
    expect(Time).to receive(:now).and_return(1)
    expect(SlackStatusBot::Listeners::AWSLambda.expiration(1))
      .to eq(2)
  end
  example 'It returns the time provided if parsed time is greater than 1_000_000_000 seconds' do
    expect(Time).to receive(:now).and_return(1)
    expect(SlackStatusBot::Listeners::AWSLambda.expiration(1_000_000_001))
      .to eq(1_000_000_002)
  end

  example 'It returns 0 if no time provided' do
    expect(SlackStatusBot::Listeners::AWSLambda.expiration(nil))
      .to eq(0)
  end
end

describe 'Given a function that obtains parameters from an AWS Lambda API invocation' do
  context 'When it receives none' do
    example 'Then it yields none', :unit do
      fake_event = {
        'queryStringParameters': {}
      }
      expect(SlackStatusBot::Listeners::AWSLambda.params(fake_event))
        .to eq({})
    end
  end

  context 'When it receives some' do
    example 'Then it receives some', :unit do
      fake_event = {
        'queryStringParameters': {
          "foo": 'bar',
          "baz": '6'
        }
      }
      expected = {
        foo: 'bar',
        baz: '6'
      }
      expect(SlackStatusBot::Listeners::AWSLambda.params(fake_event))
        .to eq expected
    end
  end
  context 'When it receives a body instead of URL query parameters' do
    example 'it to return parameters', :unit do
      fake_event = {
        'body': {
          foo: 'bar',
          baz: '6'
        }.to_json
      }
      expected = {
        foo: 'bar',
        baz: '6'
      }
      expect(SlackStatusBot::Listeners::AWSLambda.params(fake_event))
        .to eq expected
    end
  end
end

describe 'Given a listener that sets ad-hoc status updates from AWS Lambda' do
  before(:each) do
    allow(SlackStatusBot::Listeners::AWSLambda)
      .to receive(:expiration)
      .and_return(123)
    @params = {
      status: 'fake',
      emoji: ':emoji:',
      expiration: 123
    }
  end
  example 'Then it fails if all args are missing', :unit do
    expected = {
      statusCode: 422,
      headers: {
        'Content-Type': 'application/json'
      },
      body: {
        status: 'error',
        message: 'Please provide: status, emoji'
      }.to_json
    }
    allow(SlackStatusBot::Listeners::AWSLambda)
      .to receive(:params)
      .and_return({})
    expect(SlackStatusBot::Listeners::AWSLambda.update!({}))
      .to eq(expected)
  end

  %w[status emoji].each do |key|
    example "Then it fails if #{key} is missing", :unit do
      expected = {
        statusCode: 422,
        headers: {
          'Content-Type': 'application/json'
        },
        body: {
          status: 'error',
          message: "Please provide: #{key}"
        }.to_json
      }
      allow(SlackStatusBot::Listeners::AWSLambda)
        .to receive(:params)
        .and_return(@params.reject { |k, _| k == key.to_sym })
      expect(SlackStatusBot::Listeners::AWSLambda.update!({}))
        .to eq(expected)
    end
  end

  example 'Then it does not post a status during weekends', :unit do
    expected = {
      statusCode: 422,
      headers: {
        'Content-Type': 'application/json'
      },
      body: {
        status: 'error',
        message: 'status updates are disabled during weekends, holidays, and vacations'
      }.to_json
    }
    allow(SlackStatusBot::Listeners::AWSLambda)
      .to receive(:params)
      .and_return(@params)
    allow(SlackStatusBot::Listeners::AWSLambda)
      .to receive(:weekend?)
      .and_return(true)
    expect(SlackStatusBot::Base::API)
      .not_to receive(:post_status!)
    expect(SlackStatusBot::Listeners::AWSLambda.update!({}))
      .to eq(expected)
  end

  example 'Then it does not post a status during vacations', :unit do
    expected = {
      statusCode: 422,
      headers: {
        'Content-Type': 'application/json'
      },
      body: {
        status: 'error',
        message: 'status updates are disabled during weekends, holidays, and vacations'
      }.to_json
    }
    allow(SlackStatusBot::Listeners::AWSLambda)
      .to receive(:params)
      .and_return(@params)
    allow(SlackStatusBot::Listeners::AWSLambda)
      .to receive(:weekend?)
      .and_return(false)
    allow(SlackStatusBot::Listeners::AWSLambda)
      .to receive(:currently_on_vacation?)
      .and_return(true)
    expect(SlackStatusBot::Base::API)
      .not_to receive(:post_status!)
    expect(SlackStatusBot::Listeners::AWSLambda.update!({}))
      .to eq(expected)
  end

  example 'Then it posts a status if all args are present', :unit do
    expected = {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json'
      },
      body: {
        status: 'ok'
      }.to_json
    }
    allow(SlackStatusBot::Listeners::AWSLambda)
      .to receive(:params)
      .and_return(@params)
    allow(SlackStatusBot::Listeners::AWSLambda)
      .to receive(:weekend?)
      .and_return(false)
    allow(SlackStatusBot::Listeners::AWSLambda)
      .to receive(:currently_on_vacation?)
      .and_return(false)
    expect(SlackStatusBot::Base::API)
      .to receive(:post_status!)
      .with('fake', ':emoji:', 123)
      .and_return(true)
    expect(SlackStatusBot::Listeners::AWSLambda.update!({}))
      .to eq(expected)
  end
end
