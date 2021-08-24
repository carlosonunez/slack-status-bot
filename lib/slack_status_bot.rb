require 'logger'
require 'httparty'
require 'json'
require 'slack_status_bot/base'
require 'slack_status_bot/environment'
require 'slack_status_bot/tripit'
require 'slack_status_bot/google_calendar'

module SlackStatusBot
  CITY_EMOJIS_FILE = './include/city_emojis.yml'
  TRAVEL_STATUSES_FILE = './include/travel_statuses.yml'
  EMPLOYER = ENV['TRIPIT_WORK_COMPANY_NAME']
  @logger = Logger.new(STDOUT)
  @logger.level = ENV['LOG_LEVEL'] || Logger::WARN
  def self.logger
    @logger
  end
end

raise 'App is not configured properly; see logs.' unless SlackStatusBot::Environment.configured?
