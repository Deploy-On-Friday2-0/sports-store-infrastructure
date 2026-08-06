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

assert_contains variables.tf 'default     = 2' \
  "Production config version must be bumped to 2"

assert_contains secrets.tf 'resource "aws_secretsmanager_secret_version" "production_config"' \
  "Production config secret version is missing"
assert_contains secrets.tf 'secret_id = aws_secretsmanager_secret.production_config.id' \
  "Secret version must reuse the DEP-234 secret"
assert_contains secrets.tf 'secret_string_wo = jsonencode({' \
  "Secret payload must use the write-only argument"
assert_contains secrets.tf 'secret_string_wo_version = var.production_config_version' \
  "Secret rotation version is missing"
assert_contains secrets.tf 'MONGO_INITDB_ROOT_PASSWORD = var.mongo_initdb_root_password' \
  "MongoDB credential key is missing"
assert_contains secrets.tf 'JWT_SECRET_KEY             = var.jwt_secret_key' \
  "JWT credential key is missing"
assert_contains secrets.tf 'MONGODB_REPLICA_SET_KEY    = var.mongodb_replica_set_key' \
  "MongoDB ReplicaSet key mapping is missing"
assert_contains secrets.tf 'REDIS_PASSWORD             = var.redis_password' \
  "Redis password mapping is missing"
assert_contains secrets.tf 'GOOGLE_API_KEY             = var.google_api_key' \
  "Google API key mapping is missing"
assert_contains secrets.tf 'SLACK_WEBHOOK_URL          = var.slack_webhook_url' \
  "Slack Webhook URL mapping is missing"

config_secret_count="$(grep -c 'resource "aws_secretsmanager_secret" "production_config"' secrets.tf)"
[[ "$config_secret_count" == "1" ]] || fail "The DEP-234 secret container must not be duplicated"

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
