#!/usr/bin/env ruby
$LOAD_PATH.unshift('./lib')
require 'slack_status_bot'

SlackStatusBot.update!
