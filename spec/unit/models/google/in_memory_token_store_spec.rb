# frozen_string_literal: true

require 'spec_helper'
require 'googleauth'
require 'slack_status_bot/models/google/in_memory_token_store'

describe 'Given an in-memory token store used for authenticating a Google OAuth client' do
  before do
    InMemoryTokenStore = SlackStatusBot::Models::Google::InMemoryTokenStore
  end
  context 'When it is created' do
    example "Then it successfully creates and inherits from Google's TokenStore", :unit do
      store = InMemoryTokenStore.new
      expect(store.class).to be < Google::Auth::TokenStore
    end

    example 'Then it can store new token data', :unit do
      store = InMemoryTokenStore.new
      store.store('foo', { bar: 'baaz' })
      expect(store.load('foo')[:bar]).to eq 'baaz'
    end

    example 'Then it can purge token data', :unit do
      store = InMemoryTokenStore.new
      store.store('foo', { bar: 'baaz' })
      store.store('bar', { baaz: 'quux' })
      store.delete('foo')
      expect(store.load('foo')).to be nil
      expect(store.load('bar')[:baaz]).to be 'quux'
    end
  end
end
