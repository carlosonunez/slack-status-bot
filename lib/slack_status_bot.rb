# frozen_string_literal: true

require 'logger'
require 'httparty'
require 'json'
require 'slack_status_bot/listeners'
require 'slack_status_bot/base'
require 'slack_status_bot/environment'
require 'slack_status_bot/tripit'

module SlackStatusBot
  CITY_EMOJIS_FILE = './include/city_emojis.yml'
  TRAVEL_STATUSES_FILE = './include/travel_statuses.yml'
  EMPLOYER = ENV['TRIPIT_WORK_COMPANY_NAME']
  ENABLED_INTEGRATIONS = ENV['ENABLED_INTEGRATIONS']
  @logger = Logger.new($stdout)
  @logger.level = ENV['LOG_LEVEL'] || Logger::WARN
  def self.logger
    @logger
  end

  def self.update!
    failed_updates = []
    ENABLED_INTEGRATIONS.split(',').each do |integration|
      SlackStatusBot.logger.info("Updating integration: #{integration}")
      failed_updates.append(integration) unless SlackStatusBot.const_get(integration).update!
    end
    return if failed_updates.empty?

    raise "One or more integrations failed to update: #{failed_updates}. See logs for more."
  end
end

raise 'App is not configured properly; see logs.' unless SlackStatusBot::Environment.configured?
