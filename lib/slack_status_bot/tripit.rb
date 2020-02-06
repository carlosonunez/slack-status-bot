require 'httparty'
require 'json'

module SlackStatusBot
  module TripIt
    extend SlackStatusBot::Base::Mixins
    def self.update!
      self.fetch_current_trip do |trip|
        self.generate_status_from_trip(trip) do |status, emoji|
          if self.limited_availability? and !self.weekend?
            status = status + " (My work phone is off. Availability might be limited.)"
          end
          return self.post_new_status!(status: status, emoji: emoji) ||
            raise("Unable to post status; see logs")
        end
        raise("Unable to generate a status")
      end
      SlackStatusBot.logger.warn "No trip found. Posting default status."
      self.post_default_status!
    end

    private
    def self.generate_status_from_trip(trip)
      trip_name = trip[:trip_name]
      raise "No trip found." if trip.nil? or trip_name.nil?
      
      flight = trip[:todays_flight]
      if !flight.empty? and trip_name.match?(/^#{ENV['TRIPIT_WORK_COMPANY_NAME']}:/)
        flight_info = "#{flight[:flight_number]}: #{flight[:origin]}-#{flight[:destination]}"
        emoji = ':airplane:'
        case trip_name
        when /Holiday Party/
          status = "On my way to the holiday party! #{flight_info}"
          yield(status, emoji)
        when /Contino Day/
          status = "On my way to Contino Day! #{flight_info}"
          emoji = ":continopug:"
          yield(status, emoji)
        when /^#{ENV['TRIPIT_WORK_COMPANY_NAME']}/
          client = trip_name.gsub("#{ENV['TRIPIT_WORK_COMPANY_NAME']}: ","").gsub(/ - Week.*$/,'')
          status = "#{client}: #{flight_info}"
          yield(status, emoji)
        else
          raise "This trip doesn't have a valid name. Fix it in TripIt."
        end
      else
        case trip_name
        when /Holiday Party/
          status = "Partying it up!"
          emoji = ":tophat:"
          yield(status, emoji)
        when /Contino Day/
          status = "Contino Day"
          emoji = ":continopug:"
          yield(status, emoji)
        when /^#{ENV['TRIPIT_WORK_COMPANY_NAME']}:/
          if trip_name.match?(/- Remote$/)
            current_city = "Home"
            emoji = ':house_with_garden:'
          else
            current_city = trip[:current_city]
            emoji = self.get_emoji_for_city(current_city)
          end
          client = trip_name.gsub("#{ENV['TRIPIT_WORK_COMPANY_NAME']}: ","").gsub(/ - Week.*$/,'')
          status = "#{client} @ #{current_city}"
          yield(status, emoji)
        when /^Personal:/
          status = "Vacationing!"
          emoji = ":palm_tree:"
          yield(status, emoji)
        else
          raise "This trip doesn't have a valid name. Fix it in TripIt."
        end
      end
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
