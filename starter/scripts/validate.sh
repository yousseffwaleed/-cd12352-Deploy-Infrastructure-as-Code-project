#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"

command -v aws >/dev/null 2>&1 || { echo "AWS CLI is required." >&2; exit 1; }

aws cloudformation validate-template \
  --template-body "file://$ROOT_DIR/network.yml" \
  --region "$REGION" >/dev/null

aws cloudformation validate-template \
  --template-body "file://$ROOT_DIR/udagram.yml" \
  --region "$REGION" >/dev/null

printf 'Both CloudFormation templates are valid in %s.\n' "$REGION"
