#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"
NETWORK_STACK_NAME="${NETWORK_STACK_NAME:-udagram-network}"
APP_STACK_NAME="${APP_STACK_NAME:-udagram-app}"

command -v aws >/dev/null 2>&1 || { echo "AWS CLI is required." >&2; exit 1; }
aws sts get-caller-identity --region "$REGION" >/dev/null || {
  echo "AWS credentials are missing or invalid. Configure them before deploying." >&2
  exit 1
}

stack_exists() {
  aws cloudformation describe-stacks --stack-name "$1" --region "$REGION" >/dev/null 2>&1
}

wait_for_stack() {
  local stack_name="$1"
  local action="$2"
  aws cloudformation "wait" "stack-${action}-complete" \
    --stack-name "$stack_name" \
    --region "$REGION"
}

deploy_stack() {
  local stack_name="$1"
  local template_file="$2"
  local parameter_file="$3"
  local output

  if stack_exists "$stack_name"; then
    echo "Updating $stack_name..."
    if ! output=$(aws cloudformation update-stack \
      --stack-name "$stack_name" \
      --template-body "file://$template_file" \
      --parameters "file://$parameter_file" \
      --capabilities CAPABILITY_IAM \
      --region "$REGION" 2>&1); then
      if [[ "$output" == *"No updates are to be performed"* ]]; then
        echo "$stack_name is already up to date."
        return 0
      fi
      printf '%s\n' "$output" >&2
      return 1
    fi
    wait_for_stack "$stack_name" update
  else
    echo "Creating $stack_name..."
    aws cloudformation create-stack \
      --stack-name "$stack_name" \
      --template-body "file://$template_file" \
      --parameters "file://$parameter_file" \
      --capabilities CAPABILITY_IAM \
      --region "$REGION" >/dev/null
    wait_for_stack "$stack_name" create
  fi

  echo "$stack_name is ready."
}

"$SCRIPT_DIR/validate.sh"
deploy_stack "$NETWORK_STACK_NAME" "$ROOT_DIR/network.yml" "$ROOT_DIR/network-parameters.json"
deploy_stack "$APP_STACK_NAME" "$ROOT_DIR/udagram.yml" "$ROOT_DIR/udagram-parameters.json"

echo "Deployment complete. Application outputs:"
aws cloudformation describe-stacks \
  --stack-name "$APP_STACK_NAME" \
  --query 'Stacks[0].Outputs' \
  --output table \
  --region "$REGION"
