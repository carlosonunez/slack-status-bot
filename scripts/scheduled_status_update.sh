#!/usr/bin/env bash
DEFAULT_ENV_FILE="${TOPLEVEL}/.env"
DEFAULT_UPDATE_STATUS_STORAGE_DIR=/tmp
DEFAULT_ENDPOINT_TIMEOUT_THRESHOLD=5
TOPLEVEL="$(realpath "$(dirname "$0")/..")"
ENV_FILE="${ENV_FILE:-$DEFAULT_ENV_FILE}"
UPDATE_STATUS_STORAGE_DIR="${UPDATE_STATUS_STORAGE_DIR:-$DEFAULT_UPDATE_STATUS_STORAGE_DIR}"
ENDPOINT_TIMEOUT_THRESHOLD="${ENDPOINT_TIMEOUT_THRESHOLD:-$DEFAULT_ENDPOINT_TIMEOUT_THRESHOLD}"
LOG_LEVEL="${LOG_LEVEL:-info}"

usage() {
  cat <<-EOF
[ENV_VARS] $(basename "$0") [OPTS]
Helper script to update statuses on a schedule.

OPTIONS

  -h, --help        Shows this help text.

ENVIRONMENT VARIABLES

  UPDATE_STATUS_STORAGE_DIR   Directory to store temporary files used by this script.
                              (Default: $DEFAULT_UPDATE_STATUS_STORAGE_DIR)

  ENV_FILE                    An environment dotfile to use for configuration.
                              (Default: $DEFAULT_ENV_FILE)

  SMTP_SERVER                 SMTP server to use for sending email notifications.
  
  SMTP_USERNAME               Username to log into the SMTP server with.

  SMTP_PASSWORD               Password to log into the SMTP server with.

  SMTP_EMAIL_FROM             The email address failure emails should be sent from.

  SMTP_EMAIL_TO               The email address to send failure emails to.

  LOG_LEVEL                   Logging verbosity for the app.

  ENDPOINT_TIMEOUT_THRESHOLD  The number of times the TripIt API will need to timeout
                              before sending an email.
                              (Default: $DEFAULT_ENDPOINT_TIMEOUT_THRESHOLD)
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

_send_email() {
  for var in SERVER USERNAME PASSWORD EMAIL_FROM EMAIL_TO
  do
    k="SMTP_$var"
    if test -z "${!k}"
    then
      warn "failure email not sent because $k is not defined"
      return 1
    fi
  done
  local body subject
  subject="$1"
  body="$2"
  envelope="$(cat <<-EOF
From: $SMTP_EMAIL_FROM
To: $SMTP_EMAIL_TO
Subject: "$subject"

$body
EOF
)"
  info "Sending email to $SMTP_EMAIL_TO: $subject"
  curl -u "${SMTP_USERNAME}:${SMTP_PASSWORD}" \
    "smtps://${SMTP_SERVER}:465" \
    --mail-from "$SMTP_EMAIL_FROM" \
    --mail-rcpt "$SMTP_EMAIL_TO" \
    --upload-file <(echo "$envelope")
}

_environment() {
  basename "$ENV_FILE"
}

_slack_custom_status_file() {
  printf "%s/.slack_custom_status_sentinel_%s" \
    "$UPDATE_STATUS_STORAGE_DIR" \
    "$(base64 -w 0 <<< "$(_environment)")"
}

_tripit_endpoint_timeout_count_file() {
  printf "%s/.tripit_endpoint_timeout_count_%s" \
    "$UPDATE_STATUS_STORAGE_DIR" \
    "$(base64 -w 0 <<< "$(_environment)")"
}

_clear_tripit_endpoint_timeout_count() {
  echo 0 > "$(_tripit_endpoint_timeout_count_file)"
}

_tripit_endpoint_timeout_count() {
  test -f "$(_tripit_endpoint_timeout_count_file)" || _clear_tripit_endpoint_timeout_count
  cat "$(_tripit_endpoint_timeout_count_file)"
}

_increase_tripit_endpoint_timeout_count() {
  echo "$(_tripit_endpoint_timeout_count) + 1" | bc > "$(_tripit_endpoint_timeout_count_file)"
}

_set_slack_custom_status_sentinel() {
  info "Setting custom status sentinel"
  now=$(date +%s)
  one_hour_in_seconds=3600
  echo "$one_hour_in_seconds + $now" | bc > "$(_slack_custom_status_file)"
}

_delete_slack_custom_status_sentinel() {
  rm "$(_slack_custom_status_file)"
}

_slack_custom_status_sentinel_expired() {
  expiry=$(cat "$(_slack_custom_status_file)")
  now=$(date +%s)
  debug "expiry: $expiry; now: $now; expired? $(test "$now" -gt "$expiry"; echo $?)"
  test "$now" -gt "$expiry"
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

debug() {
  _log "debug" "$1"
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
  _send_email '[ALERT] Status update failed :(' "$(cat <<-EOF
A scheduled status update failed.

Time: "$(date -Iseconds)"
Environment: $ENV_FILE

What happened:

$result
EOF
)"
}

slack_custom_status_set() {
  local result
  result="$1"
  grep -q "Current status has not expired yet" <<< "$result"
}

tripit_endpoint_request_timed_out() {
  grep -q "Endpoint request timed out" <<< "$1"
}

send_tripit_endpoint_timeout_email() {
  debug "TripIt endpoint timeouts: $(_tripit_endpoint_timeout_count); threshold: $ENDPOINT_TIMEOUT_THRESHOLD"
  if test "$(_tripit_endpoint_timeout_count)" -ge "$ENDPOINT_TIMEOUT_THRESHOLD"
  then
    info "Endpoint timeout threshold crossed. Sending email."
    _send_email '[ERROR] TripIt endpoint not responding' "$(cat <<-EOF
Environment: $(_environment)

The TripIt API endpoint has not responded the last five times. It might be down.
EOF
)"
    _clear_tripit_endpoint_timeout_count
  fi
  _increase_tripit_endpoint_timeout_count
}

send_slack_custom_status_email() {
  if ! test -f "$(_slack_custom_status_file)" || _slack_custom_status_sentinel_expired
  then
    _send_email '[WARN] Custom status active' "$(cat <<-EOF
Environment: $(_environment)

A custom status is currently set. This alert will be sent every hour during
which the status is set.
EOF
)"
    if test -f "$(_slack_custom_status_file)"
    then info "Custom status sentinel set; set to expire on $(cat _slack_custom_status_file)"
    else _set_slack_custom_status_sentinel
    fi
  fi
}

run_update() {
  pushd /app || return 1
  info "Running status update with log level $LOG_LEVEL"
  LOG_LEVEL="${LOG_LEVEL}" ENV_FILE="${ENV_FILE}" ruby bin/update.rb 2>&1
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
result=$(run_update)
rc="$?"
if test "${LOG_LEVEL,,}" == 'debug'
then
  debug "Last status update run:"
  info "$result"
fi
if test "$rc" == 0
then
  info "Status update was successful"
  _delete_slack_custom_status_sentinel
  _clear_tripit_endpoint_timeout_count
  exit 0
fi
if slack_custom_status_set "$result"
then
  warn "Custom status set"
  send_slack_custom_status_email
  exit 1
fi
if tripit_endpoint_request_timed_out "$result"
then
  warn "TripIt Endpoint request timed out"
  send_tripit_endpoint_timeout_email
  exit 1
fi
error "Status update was not successful: $result"
send_failure_email "$result"
exit 1
