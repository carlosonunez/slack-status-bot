#!/usr/bin/env ruby
$LOAD_PATH.unshift('./lib')

require 'slack-update-bot'
enabled_integrations = [
  'TripIt'
]
enabled_integrations.each do |integration|
  SlackStatusBot.const_get(integration).update!
end
