#!/usr/bin/env bash
TOPLEVEL="$(realpath "$(dirname "$0")/..")"
DEFAULT_ENV_FILE="${TOPLEVEL}/.env"
ENV_FILE="${ENV_FILE:-$DEFAULT_ENV_FILE}"

usage() {
  cat <<-EOF
[ENV_VARS] $(basename "$0") [OPTS]
Helper script to update statuses on a schedule.

OPTIONS

  -h, --help        Shows this help text.

ENVIRONMENT VARIABLES

  ENV_FILE          An environment dotfile to use for configuration.
                    (Default: $DEFAULT_ENV_FILE)

  SMTP_SERVER       SMTP server to use for sending email notifications.
  
  SMTP_USERNAME     Username to log into the SMTP server with.

  SMTP_PASSWORD     Password to log into the SMTP server with.

  SMTP_EMAIL_FROM   The email address failure emails should be sent from.

  SMTP_EMAIL_TO     The email address to send failure emails to.

NOTE

  - All environment variables supported by Slack Status Bot are also
    accepted here.

  - Ensure that your domain can send emails from SMTP_EMAIL_FROM.
EOF
}

_log() {
  local level message
  level="${1^^}"
  message="$2"
  continued=0
  while read -r line
  do
    ts="$(date +%s)"
    test "$continued" -eq 1 && line="---> $line"
    >&2 printf '{"level": "%s", "timestamp": "%s", "message": "%s"}\n' "$level" "$ts" "$line"
    continued=1
  done <<< "$message"
}

error() {
  _log "error" "$1"
}

warn() {
  _log "warn" "$1"
}

info() {
  _log "info" "$1"
}

ensure_running_in_container_or_exit() {
  { test -f "/.dockerenv" || test -n "$KUBERNETES_SERVICE_PORT"; } && return 0

  error "This script needs to run within a container."
  exit 1
}

ensure_prerequisites_met_or_exit() {
  test -f "/.slack_status_bot_configured" && return 0

  error "This script needs to run from a container created by the slack-status-bot image."
  exit 1
}

send_failure_email() {
  for var in SERVER USERNAME PASSWORD EMAIL_FROM EMAIL_TO
  do
    k="SMTP_$var"
    if test -z "${!k}"
    then
      warn "failure email not sent because $k is not defined"
      return 1
    fi
  done
  local result
  result="$1"
  body=$(cat <<-EOF
From: $SMTP_EMAIL_FROM
To: $SMTP_EMAIL_TO
Subject: [ALERT] Status update failed :(

A scheduled status update failed.

Time: "$(date -Iseconds)"
Environment: $ENV_FILE

What happened:

$result
EOF
)
  curl -u "${SMTP_USERNAME}:${SMTP_PASSWORD}" \
    "smtps://${SMTP_SERVER}:465" \
    --mail-from "$SMTP_EMAIL_FROM" \
    --mail-rcpt "$SMTP_EMAIL_TO" \
    --upload-file <(echo "$body")
}

run_update() {
  pushd /app || return 1
  info "Running status update"
  ENV_FILE="${ENV_FILE}" ruby bin/update.rb 2>&1
  rc=$?
  popd || return 1
  return "$rc"
}

if grep -Eq -- '-h|--help' <<< "$@"
then
  usage
  exit 0
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a
ensure_running_in_container_or_exit
ensure_prerequisites_met_or_exit

info "Using environment: $ENV_FILE"
if result=$(run_update)
then
  info "Status update was successful"
  exit 0
fi
error "Status update was not successful: $result"
send_failure_email "$result"
exit 1
