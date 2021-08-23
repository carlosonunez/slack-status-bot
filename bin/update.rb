#!/usr/bin/env ruby
$LOAD_PATH.unshift('./lib')
require 'slack_status_bot'

enabled_integrations = [
  'TripIt'
]
failed_updates = []
enabled_integrations.each do |integration|
  SlackStatusBot.logger.info("Updating integration: #{integration}")
  failed_updates.append(integration) unless SlackStatusBot.const_get(integration).update!
end
raise "One or more integrations failed to update: #{failed_updates}. See logs for more." unless failed_updates.empty?
