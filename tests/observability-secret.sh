#!/usr/bin/env bash

set -euo pipefail

# Static acceptance test for the Terraform-managed observability secret
# (sports-store/production/observability). Grafana's admin login and the
# Alertmanager Slack webhook were previously provisioned entirely
# out-of-band (never reproduced by Terraform), so a deleted secret required
# manual recovery. Terraform now owns the secret container and generates the
# Grafana credential itself; only the Slack webhook remains a human-supplied
# value (reusing the existing slack_webhook_url variable), since Terraform
# cannot invent a real external credential.

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

assert_contains providers.tf 'source  = "hashicorp/random"' \
  "The random provider is required to generate the Grafana admin password"

assert_contains secrets.tf 'resource "random_password" "grafana_admin"' \
  "Grafana admin password generator is missing"

assert_contains secrets.tf 'resource "aws_secretsmanager_secret" "production_observability"' \
  "Observability secret resource is missing"
assert_contains secrets.tf 'name       = "sports-store/production/observability"' \
  "Observability secret name is incorrect"
assert_contains secrets.tf 'kms_key_id = "alias/aws/secretsmanager"' \
  "Observability secret must use the AWS managed Secrets Manager KMS key"

observability_secret_count="$(grep -c 'resource "aws_secretsmanager_secret" "production_observability"' secrets.tf)"
[[ "$observability_secret_count" == "1" ]] || fail "The observability secret container must be declared exactly once"

assert_contains secrets.tf 'resource "aws_secretsmanager_secret_version" "production_observability"' \
  "Observability secret version is missing"
assert_contains secrets.tf 'secret_id = aws_secretsmanager_secret.production_observability.id' \
  "Observability secret version must reuse the observability secret container"
assert_contains secrets.tf 'GRAFANA_ADMIN_USER     = "admin"' \
  "Grafana admin user mapping is missing"
assert_contains secrets.tf 'GRAFANA_ADMIN_PASSWORD = random_password.grafana_admin.result' \
  "Grafana admin password must come from the Terraform-generated random_password"
assert_contains secrets.tf 'SLACK_WEBHOOK_URL = var.slack_webhook_url' \
  "Alertmanager Slack webhook mapping is missing"
assert_contains secrets.tf 'secret_string_wo_version = var.production_observability_version' \
  "Observability secret rotation version is missing"

assert_contains variables.tf 'variable "production_observability_version"' \
  "production_observability_version variable is missing"

# Prevent readable secret payload arguments from introducing values into state.
for f in *.tf; do
  if grep -E -q 'secret_string[[:space:]]*=|secret_binary[[:space:]]*=' "$f"; then
    fail "A state-backed secret payload argument was found in $f"
  fi
done

printf 'Observability secret acceptance tests passed.\n'
