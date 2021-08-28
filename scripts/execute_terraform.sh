#!/usr/bin/env bash
if ! . "$(dirname "$0")/helpers/shared_secrets.sh"
then
  >&2 echo "ERROR: Unable to load shared secret helpers."
  exit 1
fi
TERRAFORM_STATE_S3_KEY="${TERRAFORM_STATE_S3_KEY?Please provide a S3 key to store TF state in.}"
TERRAFORM_STATE_S3_BUCKET="${TERRAFORM_STATE_S3_BUCKET?Please provide a S3 bucket to store state in.}"
AWS_REGION="${AWS_REGION?Please provide an AWS region.}"
AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID?Please define AWS_ACCESS_KEY_ID}"
AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY?Please define AWS_SECRET_ACCESS_KEY}"
AWS_SESSION_TOKEN="${AWS_SESSION_TOKEN?Please define AWS_SESSION_TOKEN}"
ENVIRONMENT="${ENVIRONMENT:-test}"

set -e
action=$1
shift

export TF_VAR_environment=$ENVIRONMENT

terraform init -backend-config="bucket=${TERRAFORM_STATE_S3_BUCKET}" \
  -backend-config="key=${TERRAFORM_STATE_S3_KEY}/${ENVIRONMENT}" \
  -backend-config="region=$AWS_REGION"

terraform "$action" "$@" && \
  if [ "$action" == "apply" ]
  then
    mkdir -p ./secrets
    for output_var in app_account_ak app_account_sk certificate_arn
    do
      write_secret "$(terraform output "$output_var")" "$output_var"
    done
  fi
