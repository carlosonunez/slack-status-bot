module SlackStatusBot
  module Environment
    @optional_environment_variables = [
      'LOG_LEVEL'
    ]
    def self.configured?
      # Unfortunately there isn't a native `grep` like way of searching for
      # strings within files that doesn't require loading the entire file
      # into memory first. So we'll use the people's champion himself instead.
      if !self.gnu_grep_installed?
        SlackStatusBot.logger.error "GNU grep not installed on this system; can't resolve env"
        return false
      else
        search_pattern = "ENV\\['\[A-Z0-9_\]+'\\]"
        `egrep --only-matching --no-filename --recursive "#{search_pattern}"`
          .split("\n")
          .uniq
          .map {|match| match.gsub(/ENV\['(.*)'\]/,'\1')}
          .select {|environment_variable|
            !@optional_environment_variables.include? environment_variable
          }
          .each do |environment_variable|
            if ENV[environment_variable].nil?
              SlackStatusBot.logger.error "Missing env var: #{environment_variable}"
              return false
            end
        end
        if !File.exist? SlackStatusBot::CITY_EMOJIS_FILE
          SlackStatusBot.logger.error "Missing city emojis file."
          return false
        end
        return true
      end
    end

    private
    def self.gnu_grep_installed?
      system('which egrep>/dev/null') and `grep --version`.split("\n")[2].match?(/GNU GPL/)
    end
  end
end
