# frozen_string_literal: true

require 'logger'

module SlackStatusBot
  # A very quick and dirty unified logging class.
  module Logging
    DEFAULT_LEVEL = ::Logger::WARN

    @loggers = {}

    def logger
      @logger ||= Logging.logger_for(self.class.name)
    end

    class << self
      def logger_for(class_name)
        @loggers[class_name] ||= configure_logger_for(class_name)
      end

      def configure_logger_for(class_name)
        logger = Logger.new($stdout)
        logger.level = ENV["#{class_name.upcase}_LOG_LEVEL"] ||
                       ENV['LOG_LEVEL'] ||
                       DEFAULT_LEVEL
        logger.progname = class_name
        logger
      end
    end
  end
end
