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

  def self.update!(ignore_status_expiration: false)
    failed_updates = []
    SlackStatusBot.logger.debug("Enabled integrations: #{ENABLED_INTEGRATIONS}")
    ENABLED_INTEGRATIONS.split(',').each do |integration|
      SlackStatusBot.logger.info("Updating integration: #{integration}")
      status_updated, error_message =
        SlackStatusBot.const_get(integration).update!(ignore_status_expiration: ignore_status_expiration)
      error_message = 'No error message generated' if error_message.nil? || error_message.empty?
      next if status_updated

      failed_updates.append({
                              integration: integration,
                              error_message: error_message
                            })
    end
    return if failed_updates.empty?

    raise "One or more integrations failed to update: #{JSON.generate(failed_updates)}. See logs for more."
  end
end

raise 'App is not configured properly; see logs.' unless SlackStatusBot::Environment.configured?
