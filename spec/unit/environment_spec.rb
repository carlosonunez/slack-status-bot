# frozen_string_literal: true

require 'spec_helper'

describe 'Given the slack-status-bot project' do
  context 'When I run it' do
    example 'It has a configured environment', :unit do
      expect(SlackStatusBot::Environment.configured?).to be true
    end
  end
end
