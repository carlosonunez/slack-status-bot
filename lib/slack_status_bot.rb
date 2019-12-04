require 'logger'
require 'httparty'
require 'json'
require 'slack_status_bot/base'
require 'slack_status_bot/environment'
require 'slack_status_bot/tripit'

module SlackStatusBot
  CITY_EMOJIS_FILE = './include/city_emojis.yml'
  @logger = Logger.new(STDOUT)
  @logger.level = ENV['LOG_LEVEL'] || Logger::WARN
  def self.logger
    @logger
  end
end

raise 'App is not configured properly; see logs.' if !SlackStatusBot::Environment.configured?
