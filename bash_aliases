# source this file into your Bash or zsh session to make some common
# commands available to you while testing the Slack API.
alias unit="nc -z localhost 8000 || docker-compose up -d dynamodb; docker-compose run --service-ports --rm unit"
alias deploy="scripts/deploy"
