#!/usr/bin/env bash

set -euo pipefail

# Lightweight static acceptance test for DEP-234. It verifies the Terraform
# configuration without requiring AWS credentials or access to Terraform state.

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

# Verify the secret container's name, encryption key, and required tags.
assert_contains secrets.tf 'resource "aws_secretsmanager_secret" "production_config"' \
  "Secrets Manager secret resource is missing"
assert_contains secrets.tf 'name       = "sports-store/production/config"' \
  "Secret name is incorrect"
assert_contains secrets.tf 'kms_key_id = "alias/aws/secretsmanager"' \
  "Secret must use the AWS managed Secrets Manager KMS key"
assert_contains secrets.tf 'Project     = "sports-store"' \
  "Secret project tag is missing"
assert_contains secrets.tf 'Environment = var.environment' \
  "Secret environment tag is missing"

# Ensure the policy contains exactly the two approved Secrets Manager actions.
expected_actions='"secretsmanager:DescribeSecret"
"secretsmanager:GetSecretValue"'
actual_actions="$(rg --only-matching '"secretsmanager:[^"]+"' iam.tf | LC_ALL=C sort -u)"
[[ "$actual_actions" == "$expected_actions" ]] || fail "Secrets Manager IAM actions are not least privilege"

# Verify the secret path scope, EKS Pod Identity trust, policy attachment, and
# External Secrets namespace/service-account association.
assert_contains iam.tf 'Resource = "arn:aws:secretsmanager:*:*:secret:sports-store/*"' \
  "IAM policy scope is incorrect"
assert_contains iam.tf 'Service = "pods.eks.amazonaws.com"' \
  "Pod Identity trust principal is missing"
assert_contains iam.tf '"sts:AssumeRole"' "Pod Identity AssumeRole action is missing"
assert_contains iam.tf '"sts:TagSession"' "Pod Identity TagSession action is missing"
assert_contains iam.tf 'policy_arn = aws_iam_policy.external_secrets.arn' \
  "Secrets Manager policy is not attached to the Pod Identity role"
assert_contains iam.tf 'cluster_name    = var.cluster_name' \
  "Pod Identity association does not target the configured EKS cluster"
assert_contains iam.tf 'namespace       = "external-secrets"' \
  "Pod Identity namespace is incorrect"
assert_contains iam.tf 'service_account = "external-secrets-sa"' \
  "Pod Identity service account is incorrect"

# Prevent this issue from introducing secret values into Terraform or state.
if rg --glob '*.tf' --glob '*.tfvars' \
  'aws_secretsmanager_secret_version|secret_string\s*=|secret_binary\s*=' .; then
  fail "Static secret values or a secret version resource were found"
fi

printf 'DEP-234 acceptance tests passed.\n'
