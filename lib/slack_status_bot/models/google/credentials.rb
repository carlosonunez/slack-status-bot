# frozen_string_literal: true

require 'dynamoid'

module SlackStatusBot
  module Models
    module Google
      # This model represents a stored representation of access and refresh tokens.
      class Credentials
        include Dynamoid::Document

        table(name: :tokens,
              key: :client_id,
              read_capacity: 2,
              write_capacity: 2)

        field(:client_id)
        field(:access_token)
        field(:refresh_token)
      end
    end
  end
end
