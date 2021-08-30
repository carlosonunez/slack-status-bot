#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift('./lib')
require 'slack_status_bot'

def self.ignore_slack_status_expiration?(args)
  args.select { |arg| ['--ignore-slack-status-expiration'].include?(arg) }.length.positive?
end

def show_help_and_quit(args)
  asked_for_help = args.select { |arg| ['-h', '--help'].include?(arg) }.length.positive?
  return unless asked_for_help

  puts USAGE
  exit(0)
end

USAGE = <<~TEXT
  #{$PROGRAM_NAME} [OPTIONS]
  Updates statuses on various platforms

  OPTIONS

    -h, --help                                Show this usage text

  SLACK RECEIVER OPTIONS

        --ignore-slack-status-expiration      Updates your profile regardless of whether
                                              your current Slack status has an expiration time.

  NOTES

  ## Forcing status updates

  When --force is enabled, the following will occur:

  - The 'slack' status updater will ignore any expiration times set on your current status.
TEXT

show_help_and_quit(ARGV)
if ignore_slack_status_expiration?(ARGV)
  SlackStatusBot.update!(ignore_status_expiration: true)
else
  SlackStatusBot.update!
end
