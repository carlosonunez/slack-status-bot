# source this file into your Bash or zsh session to make some common
# commands available to you while testing the Slack API.
alias unit="docker-compose up -d dynamodb && docker-compose run --rm unit && docker-compose down"
alias deploy="scripts/deploy"
