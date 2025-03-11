require 'erb'
require 'httparty'
require 'json'
require 'yaml'

module SlackStatusBot
  module TripIt
    extend SlackStatusBot::Base::Mixins
    def self.update!(ignore_status_expiration: false)
      fetch_current_trip do |trip|
        generate_status_from_trip(trip) do |status, emoji|
          return post_default_status!(ignore_status_expiration: ignore_status_expiration) if status.nil?

          if limited_availability? && !weekend? && !on_vacation?(status)
            status += ' (unavailable)'
            emoji = ':sleeping:'
          end
          return post_new_status!(status: status,
                                  emoji: emoji,
                                  ignore_status_expiration: ignore_status_expiration)
        end
      rescue StandardError => e
        return false, e
      end
      SlackStatusBot.logger.warn 'No trip found. Posting default status.'
      post_default_status!(ignore_status_expiration: ignore_status_expiration)
    end

    def self.currently_flying_on_work_trip?(trip)
      flight = trip[:todays_flight]
      !flight.empty?
    end

    def self.ooo_return_date(trip)
      trip.gsub(/^Vacation: .* until (.*)$/, '\1')
    end

    def self.training_return_date(trip)
      trip.gsub(/^.*\[training\].* until (.*)$/, '\1')
    end

    def self.beach_return_date(trip)
      trip.gsub(/^.*Beach: .* until (.*)$/, '\1')
    end

    def self.conf_return_date(trip)
      trip.gsub(/^.*Conference: .* until (.*)$/, '\1')
    end

    def self.team_offsite_return_date(trip)
      trip.gsub(/^.*(o|O)ffsite until (.*)$/, '\2')
    end

    def self.burst_week_return_date(trip)
      trip.gsub(/^.*Burst Week until (.*)$/, '\2')
    end

    def self.conf_name(trip)
      trip.gsub(/^.*Conference: (.*) until.*$/, '\1')
    end

    def self.render_travel_statuses
      container = ERB.new(File.read(SlackStatusBot::TRAVEL_STATUSES_FILE))
      container.result
    end

    def self.get_status_and_emoji(trip)
      @statuses ||= YAML.load(File.read(SlackStatusBot::TRAVEL_STATUSES_FILE),
                              symbolize_names: true)
      raise 'No statuses found.' if @statuses.nil?

      trip_name = trip[:trip_name]
      found_status =
        @statuses.select do |status_info|
          template_variables = binding
          template_variables.local_variable_set(:employer, ENV['TRIPIT_WORK_COMPANY_NAME'])
          regexp = ERB.new(status_info[:status_regexp]).result(template_variables)
          SlackStatusBot.logger.debug("Trip: [#{trip_name}], Regexp: [#{regexp}]")
          if Regexp.new(regexp).match? trip_name
            SlackStatusBot.logger.debug("It's a match!: #{trip_name}")
            true
          end
        end.first
      return nil if found_status.nil? || found_status.empty?

      SlackStatusBot.logger.debug("Found status: #{found_status}")
      found_status
    end

    def self.client(trip_name)
      SlackStatusBot.logger.debug("Trip name: [#{trip_name}]")
      if /.*- Week [0-9]{1,}/.match? trip_name
        trip_name.gsub(/- Remote$/, '').gsub(/^\w+:(.*) - Week.*/, '\1').strip
      else
        trip_name.gsub(/- Remote$/, '').gsub(/^\w+:(.*)/, '\1').strip
      end
      trip_name.gsub(/\[.*\]/, '').gsub(/ {2,}/, ' ').gsub(/(.*) until.*/, '\1').strip
    end

    def self.generate_status_from_trip(trip)
      raise 'No trip found.' if trip.nil?

      current_city = trip[:current_city]
      template_variables = binding
      template_variables.local_variable_set(:current_city, current_city)
      template_variables.local_variable_set(:city_emoji, get_emoji_for_city(current_city))
      template_variables.local_variable_set(:trip_name, trip[:trip_name])
      status_info = get_status_and_emoji(trip)
      raise 'The name for your current trip in TripIt is invalid.' if status_info.nil?

      status_info_key = if currently_flying_on_work_trip?(trip)
                          flight = trip[:todays_flight]
                          flight_info = "#{flight[:flight_number]}: #{flight[:origin]}-#{flight[:destination]}"
                          template_variables.local_variable_set(:flight_info, flight_info)
                          :flying
                        else
                          :not_flying
                        end
      status_and_emoji = status_info[status_info_key]
      status = ERB.new(status_and_emoji[:status]).result(template_variables)
      emoji = ERB.new(status_and_emoji[:emoji]).result(template_variables)
      yield(status, emoji)
    end

    def self.fetch_current_trip
      uri = [ENV['TRIPIT_API_URL'], 'current_trip'].join('/')
      response = HTTParty.get(uri, headers: {
                                'x-api-key': ENV['TRIPIT_API_KEY']
                              })
      raise "Failed to get current trip: #{response.body}" if response.code.to_i != 200

      trip = JSON.parse(response.body, symbolize_names: true)[:trip]
      SlackStatusBot.logger.debug("Current trip: #{trip}")
      return nil if trip.nil? || trip.empty?

      yield trip
    end

    def self.get_emoji_for_city(city)
      emoji = YAML.load(File.read(SlackStatusBot::CITY_EMOJIS_FILE))[city]
      if !emoji
        SlackStatusBot.logger.warn "No emoji found for city #{city}; sending the briefcase"
        ':briefcase:'
      else
        emoji
      end
    end
  end
end
