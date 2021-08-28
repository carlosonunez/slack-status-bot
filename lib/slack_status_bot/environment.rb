module SlackStatusBot
  module Environment
    @required_environment_variables = %w[
      SLACK_API_DEFAULT_STATUS
      SLACK_API_DEFAULT_STATUS_EMOJI
      SLACK_API_KEY
      TRIPIT_WORK_COMPANY_NAME
      TRIPIT_API_URL
      TRIPIT_API_KEY
    ]
    @optional_environment_variables = [
      'LOG_LEVEL'
    ]
    def self.configured?
      vars_to_scan = @required_environment_variables.reject do |var|
        @optional_environment_variables.include? var
      end
      vars_to_scan.each do |environment_variable|
        if ENV[environment_variable].nil?
          SlackStatusBot.logger.error "Missing env var: #{environment_variable}"
          return false
        end
      end
      unless File.exist? SlackStatusBot::CITY_EMOJIS_FILE
        SlackStatusBot.logger.error 'Missing city emojis file.'
        return false
      end
      true
    end
  end
end
