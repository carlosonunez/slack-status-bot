require 'erb'
require 'httparty'
require 'json'

module SlackStatusBot
  module TripIt
    extend SlackStatusBot::Base::Mixins
    def self.update!
      self.fetch_current_trip do |trip|
        self.generate_status_from_trip(trip) do |status, emoji|
          return self.post_default_status! if status.nil?
          if self.limited_availability? and !self.weekend?
            status = status + " (My work phone is off. Availability might be limited.)"
          end
          return self.post_new_status!(status: status, emoji: emoji)
        end
      end
      SlackStatusBot.logger.warn "No trip found. Posting default status."
      self.post_default_status!
    end

    private
    def self.currently_flying_on_work_trip?(trip)
      flight = trip[:todays_flight]
      !flight.empty?
    end

    def self.ooo_return_date(trip)
      trip.gsub(/^Vacation: .* until (.*)$/, '\1')
    end

    def self.render_travel_statuses
      container = ERB.new(File.read(SlackStatusBot::TRAVEL_STATUSES_FILE))
      container.result()
    end

    def self.get_status_and_emoji(trip)
      @statuses ||= YAML.load(File.read(SlackStatusBot::TRAVEL_STATUSES_FILE),
                             symbolize_names: true)
      raise "No statuses found." if @statuses.nil?
      trip_name = trip[:trip_name]
      found_status =
        @statuses.select do |status_info|
          template_variables = binding
          template_variables.local_variable_set(:employer, ENV['TRIPIT_WORK_COMPANY_NAME'])
          regexp = ERB.new(status_info[:status_regexp]).result(template_variables)
          SlackStatusBot.logger.debug("Trip: [#{trip_name}], Regexp: [#{regexp}]")
          Regexp.new(regexp).match? trip_name
        end.first
      SlackStatusBot.logger.warn("Trip name: #{trip_name}, Found: #{found_status}")
      return nil if found_status.nil? or found_status.empty?
      return found_status
    end

    def self.client(trip_name)
      SlackStatusBot.logger.debug("Trip name: [#{trip_name}]")
      trip_name.gsub(/- Remote$/,"").gsub(/^\w+:(.*)- (Week.*)$/,'\1').strip
    end

    def self.generate_status_from_trip(trip)
      raise "No trip found." if trip.nil?

      current_city = trip[:current_city]
      template_variables = binding
      template_variables.local_variable_set(:current_city, current_city)
      template_variables.local_variable_set(:city_emoji, self.get_emoji_for_city(current_city))
      template_variables.local_variable_set(:trip_name, trip[:trip_name])
      status_info = self.get_status_and_emoji(trip)
      raise "The name for your current trip in TripIt is invalid." if status_info.nil?

      status_info_key = if self.currently_flying_on_work_trip?(trip)
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
      yield(status,emoji)
    end

    def self.fetch_current_trip
      uri = [ENV['TRIPIT_API_URL'], 'current_trip'].join('/')
      response = HTTParty.get(uri, headers: {
        'x-api-key': ENV['TRIPIT_API_KEY']
      })
      if response.code.to_i != 200
        SlackStatusBot.logger.error("Failed to get current trip: #{response.body}")
        return nil
      end
      trip = JSON.parse(response.body, symbolize_names: true)[:trip]
      SlackStatusBot.logger.debug("Current trip: #{trip}")
      return nil if trip.empty?
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
