#!/usr/bin/env bash

set -euo pipefail

# Static checks ensure DEP-235 cannot regress to state-backed or committed
# credentials. Runtime verification belongs in AWS and must report keys only.

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local value="$2"
  local description="$3"

  grep -F -q "$value" "$file" || fail "$description"
}

assert_ephemeral_variable() {
  local name="$1"
  local block

  block="$(awk -v variable="$name" '
    $0 ~ "^variable \"" variable "\"[[:space:]]*{" { found = 1 }
    found {
      line = $0
      openings = gsub(/{/, "", line)
      line = $0
      closings = gsub(/}/, "", line)
      depth += openings - closings
      print
      if (depth == 0) { exit }
    }
  ' variables.tf)"

  [[ -n "$block" ]] || fail "Variable $name is missing"
  echo "$block" | grep -F -q 'sensitive   = true' || \
    fail "Variable $name must be sensitive"
  echo "$block" | grep -F -q 'ephemeral   = true' || \
    fail "Variable $name must be ephemeral"
  if echo "$block" | grep -q '^[[:space:]]*default[[:space:]]*='; then
    fail "Variable $name must not have a default"
  fi
}

assert_contains providers.tf 'required_version = ">= 1.11.0, < 2.0.0"' \
  "Terraform 1.11 or newer is required for write-only values"

assert_ephemeral_variable mongo_initdb_root_password
assert_ephemeral_variable jwt_secret_key
assert_ephemeral_variable mongodb_replica_set_key
assert_ephemeral_variable redis_password
assert_ephemeral_variable google_api_key
assert_ephemeral_variable slack_webhook_url

# The production config secret is rotated out-of-band in AWS and must never
# return to Terraform management; the observability secret is the managed one
# and must keep using write-only payload arguments.
if grep -F -q 'resource "aws_secretsmanager_secret_version" "production_config"' secrets.tf; then
  fail "Production config secret must not be Terraform-managed"
fi
assert_contains secrets.tf 'resource "aws_secretsmanager_secret_version" "production_observability"' \
  "Observability secret version is missing"
assert_contains secrets.tf 'secret_id = aws_secretsmanager_secret.production_observability.id' \
  "Secret version must reuse the observability secret"
assert_contains secrets.tf 'secret_string_wo = jsonencode({' \
  "Secret payload must use the write-only argument"
assert_contains secrets.tf 'secret_string_wo_version = var.production_observability_version' \
  "Secret rotation version is missing"
assert_contains secrets.tf 'GRAFANA_ADMIN_USER     = "admin"' \
  "Grafana admin user key is missing"
assert_contains secrets.tf 'SLACK_WEBHOOK_URL = var.slack_webhook_url' \
  "Slack Webhook URL mapping is missing"

observability_secret_count="$(grep -c 'resource "aws_secretsmanager_secret" "production_observability"' secrets.tf)"
[[ "$observability_secret_count" == "1" ]] || fail "The observability secret container must not be duplicated"

# Check in all .tf files for state-backed secret payload arguments
for f in *.tf; do
  if grep -E -q 'secret_string[[:space:]]*=|secret_binary[[:space:]]*=' "$f"; then
    fail "A state-backed secret payload argument was found in $f"
  fi
done

if grep -E -q 'mongo_initdb_root_password|jwt_secret_key' outputs.tf; then
  fail "Secret values must not be exposed through Terraform outputs"
fi

printf 'DEP-235 acceptance tests passed.\n'
