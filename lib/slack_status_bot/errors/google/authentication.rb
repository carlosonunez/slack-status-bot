# frozen_string_literal: true

module SlackStatusBot
  module Errors
    module Google
      # This class contains some exceptions we might see while working
      # with Google APIs.
      module Authentication
        # We need to explicitly authenticate first before we can use these APIs.
        class NotAuthenticated < StandardError
          def initialize
            message = <<~EXCEPTION
              You need to authenticate first. Use the --authenticate-google-apis \
              command line switch to do this.
            EXCEPTION
            super(message)
          end
        end

        # Throw this when a client JSON is invalid; see client_valid? for more.
        class ClientInvalid < StandardError
          def initialize
            message = <<~EXCEPTION
              The Google client provided is invalid; check your \
              GOOGLE_CLIENT_ID_JSON environment variable and try again.
            EXCEPTION
            super(message)
          end
        end

        # Throw this when the credentials provided are invalid
        class AuthInvalid < StandardError
          def initialize
            super('Your access token is invalid or expired; please re-authenticate')
          end
        end
      end
    end
  end
end
