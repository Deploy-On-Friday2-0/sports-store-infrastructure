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

  rg --fixed-strings --quiet "$value" "$file" || fail "$description"
}

assert_ephemeral_variable() {
  local name="$1"
  local block

  block="$(awk -v variable="$name" '
    $0 == "variable \"" variable "\" {" { found = 1 }
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
  rg --fixed-strings --quiet 'sensitive   = true' <<<"$block" || \
    fail "Variable $name must be sensitive"
  rg --fixed-strings --quiet 'ephemeral   = true' <<<"$block" || \
    fail "Variable $name must be ephemeral"
  if rg --quiet '^\s*default\s*=' <<<"$block"; then
    fail "Variable $name must not have a default"
  fi
}

assert_contains providers.tf 'required_version = ">= 1.11.0, < 2.0.0"' \
  "Terraform 1.11 or newer is required for write-only values"

assert_ephemeral_variable mongo_initdb_root_password
assert_ephemeral_variable jwt_secret_key

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

secret_container_count="$(rg --count 'resource "aws_secretsmanager_secret"' secrets.tf)"
[[ "$secret_container_count" == "1" ]] || fail "The DEP-234 secret container must not be duplicated"

if rg --glob '*.tf' --glob '*.tfvars' 'secret_string\s*=|secret_binary\s*=' .; then
  fail "A state-backed secret payload argument was found"
fi

if rg --quiet 'mongo_initdb_root_password|jwt_secret_key' outputs.tf; then
  fail "Secret values must not be exposed through Terraform outputs"
fi

printf 'DEP-235 acceptance tests passed.\n'
