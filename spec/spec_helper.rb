# frozen_string_literal: true

require 'rspec'
require 'httparty'
require 'yaml'
require 'slack_status_bot'
require_relative 'helpers'

RSpec.configure do |config|
  config.before(:each, unit: true) do
    mock_emojis_file!
  end
end

def mock_emojis_file!
  allow(File).to receive(:read)
    .and_call_original
  allow(File).to receive(:read)
    .with(SlackStatusBot::CITY_EMOJIS_FILE)
    .and_return('Anywhere, US: ":cool:"')
end
