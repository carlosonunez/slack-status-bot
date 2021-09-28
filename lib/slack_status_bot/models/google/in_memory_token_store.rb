# frozen_string_literal: true

require 'googleauth/token_store'

module SlackStatusBot
  module Models
    module Google
      # An in-memory representation of a TokenStore
      class InMemoryTokenStore < ::Google::Auth::TokenStore
        def initialize(_options = {})
          super()
          @store ||= {}
        end

        def load(id)
          @store[id]
        end

        def store(id, token)
          @store[id] = token
        end

        def delete(id)
          @store.reject! { |k| k == id }
        end
      end
    end
  end
end
