# frozen_string_literal: true

require 'spec_helper'
require 'time'

describe "Given a library that send statuses to Carlos's Slack Bot Thing" do
  before(:all) do
    @fake_status = 'fake'
    @fake_emoji = ':emoji:'
  end

  context "When determining if a status's expiration date is stale" do
    context 'And today is later than the expiration date' do
      before(:each) do
        @fake_existing_status = {
          status_text: 'fake-status',
          status_emoji: ':emoji:',
          status_expiration: 123
        }
        mocked_time = 124
        allow(Time).to receive(:now).and_return(Time.at(mocked_time))
      end
      example 'Then the status expiration date is stale', :unit do
        extend SlackStatusBot::Base::Mixins
        expect(SlackStatusBot::Base::API)
          .to receive(:get_status)
          .and_return(@fake_existing_status)
        expect(status_expiration_stale?).to be(true)
      end
    end

    context 'And today is earlier than the expiration date' do
      before(:each) do
        @fake_existing_status = {
          status_text: 'fake-status',
          status_emoji: ':emoji:',
          status_expiration: 123
        }
        mocked_time = 122
        allow(Time).to receive(:now).and_return(Time.at(mocked_time))
      end
      example 'Then the status expiration date is not stale', :unit do
        extend SlackStatusBot::Base::Mixins
        expect(SlackStatusBot::Base::API)
          .to receive(:get_status)
          .and_return(@fake_existing_status)
        expect(status_expiration_stale?).to be(false)
      end
    end
  end

  context 'When the status currently set on our profile has not expired' do
    before(:each) do
      allow(self)
        .to receive(:status_expiration_stale?)
        .and_return(false)
    end
    context 'And we are not ignoring its expiration time' do
      example 'Then the status is not modified', :unit do
        extend SlackStatusBot::Base::Mixins
        expect(SlackStatusBot::Base::API)
          .not_to receive(:post_status!)
        expect(post_new_status!(status: @fake_status, emoji: @fake_emoji))
          .to eq([false, "Current status has not expired yet"])
      end
    end
    context 'And we are ignoring its expiration time' do
      example 'Then the status is modified', :unit do
        extend SlackStatusBot::Base::Mixins
        mocked_time = 1_575_660_000
        allow(Time).to receive(:now).and_return(Time.at(mocked_time))
        expect(SlackStatusBot::Base::API)
          .to receive(:post_status!)
          .with(@fake_status, @fake_emoji)
          .and_return(true)
        expect(SlackStatusBot::Base::API)
          .not_to receive(:post_status!)
        expect(post_new_status!(status: @fake_status,
                                emoji: @fake_emoji,
                                ignore_status_expiration: true))
          .to eq(true)
      end
    end
  end

  context 'When the status currently set on our profile has expired' do
    context 'And a stale expiration date has been set' do
      before(:each) do
        allow(self)
          .to receive(:status_expiration_stale?)
          .and_return(true)
      end
      context "And it's a business day" do
        before(:each) do
          mocked_time = 1_575_660_000
          allow(Time).to receive(:now).and_return(Time.at(mocked_time))
        end
        example 'Then it posts the status without modification', :unit do
          extend SlackStatusBot::Base::Mixins
          expect(SlackStatusBot::Base::API)
            .to receive(:post_status!)
            .with(@fake_status, @fake_emoji)
            .and_return(true)
          expect(post_new_status!(status: @fake_status, emoji: @fake_emoji))
            .to eq(true)
        end
      end
      context "And it's the weekend" do
        before(:each) do
          mocked_time = 1_576_278_060
          allow(Time).to receive(:now).and_return(Time.at(mocked_time))
        end
        example 'Then it posts a fun weekend status', :unit do
          extend SlackStatusBot::Base::Mixins
          expect(SlackStatusBot::Base::API)
            .to receive(:post_status!)
            .with('Yay, weekend!', ':sunglasses:')
            .and_return(true)
          expect(post_new_status!(status: @fake_status, emoji: @fake_emoji))
            .to eq(true)
        end
      end
    end
  end
end
