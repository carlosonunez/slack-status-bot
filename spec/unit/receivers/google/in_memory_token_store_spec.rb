# frozen_string_literal: true

require 'spec_helper'
require 'slack_status_bot/receivers/google/base'
require 'slack_status_bot/receivers/google/models'
require 'googleauth'

describe 'Given an in-memory token store used for authenticating a Google OAuth client' do
  before(:all) do
    Base = SlackStatusBot::Receivers::Google::Base
  end
  context 'When it is created' do
    example "Then it successfully creates and inherits from Google's TokenStore", :unit do
      store = Base.create_local_store!
      expect(store.class).to be < Google::Auth::TokenStore
    end

    example 'Then it can store new token data', :unit do
      store = Base.create_local_store!
      store.store('foo', { bar: 'baaz' })
      expect(store.load('foo')[:bar]).to eq 'baaz'
    end

    example 'Then it can purge token data', :unit do
      store = Base.create_local_store!
      store.store('foo', { bar: 'baaz' })
      store.store('bar', { baaz: 'quux' })
      store.delete('foo')
      expect(store.load('foo')).to be nil
      expect(store.load('bar')[:baaz]).to be 'quux'
    end
  end
end
