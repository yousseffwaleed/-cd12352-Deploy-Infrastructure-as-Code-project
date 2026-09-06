#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"
NETWORK_STACK_NAME="${NETWORK_STACK_NAME:-udagram-network}"
APP_STACK_NAME="${APP_STACK_NAME:-udagram-app}"

command -v aws >/dev/null 2>&1 || { echo "AWS CLI is required." >&2; exit 1; }
aws sts get-caller-identity --region "$REGION" >/dev/null || {
  echo "AWS credentials are missing or invalid. Configure them before deleting." >&2
  exit 1
}

stack_exists() {
  aws cloudformation describe-stacks --stack-name "$1" --region "$REGION" >/dev/null 2>&1
}

delete_stack() {
  local stack_name="$1"
  if ! stack_exists "$stack_name"; then
    echo "$stack_name does not exist; skipping."
    return 0
  fi

  echo "Deleting $stack_name..."
  aws cloudformation delete-stack --stack-name "$stack_name" --region "$REGION"
  aws cloudformation wait stack-delete-complete --stack-name "$stack_name" --region "$REGION"
  echo "$stack_name deleted."
}

# Delete the application first because it imports network-stack exports.
delete_stack "$APP_STACK_NAME"
delete_stack "$NETWORK_STACK_NAME"
echo "Teardown complete."
