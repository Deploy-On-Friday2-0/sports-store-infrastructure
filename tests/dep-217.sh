#!/usr/bin/env bash

set -euo pipefail

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local value="$2"
  local description="$3"

  rg --fixed-strings --quiet -- "$value" "$file" || fail "$description"
}

workflow=".github/workflows/terraform-ci.yml"

[[ -f "$workflow" ]] || fail "Terraform CI workflow is missing"

assert_contains "$workflow" 'pull_request:' "pull request trigger is missing"
assert_contains "$workflow" 'branches: [main]' "workflow is not limited to PRs targeting main"
if rg --quiet '^[[:space:]]+paths:' "$workflow"; then
  fail "Terraform CI must run on every PR so the post-CI reviewer cannot be bypassed"
fi
assert_contains "$workflow" 'contents: read' "read-only repository permission is missing"
assert_contains "$workflow" 'actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683' \
  "checkout action is not pinned to the approved commit"
assert_contains "$workflow" 'hashicorp/setup-terraform@b9cd54a3c349d3f38e8881555d616ced269862dd' \
  "Terraform setup action is not pinned to the approved commit"
assert_contains "$workflow" 'actions/setup-python@a26af69be951a213d495a4c3e4e4022e16d87065' \
  "Python setup action is not pinned to the approved commit"
assert_contains "$workflow" 'CHECKOV_VERSION: "3.3.8"' "Checkov version is not pinned"
assert_contains "$workflow" 'terraform fmt -check -recursive -diff' "recursive format check is missing"
assert_contains "$workflow" 'directory: .' "infrastructure root is not validated"
assert_contains "$workflow" 'directory: bootstrap/oidc' "OIDC bootstrap root is not validated"
assert_contains "$workflow" 'terraform init -backend=false -lockfile=readonly' \
  "backend-safe, lock-file-safe initialization is missing"
assert_contains "$workflow" 'terraform validate -no-color' "Terraform validation is missing"
assert_contains "$workflow" '--framework terraform' "Checkov Terraform scan is missing"
assert_contains "$workflow" '--hard-fail-on HIGH,CRITICAL' \
  "Checkov does not fail HIGH and CRITICAL findings"
assert_contains "$workflow" '--soft-fail' \
  "lower-severity Checkov findings are not configured as non-blocking"
assert_contains "$workflow" "--skip-path '(^|/)\\.terraform(/|$)'" \
  "downloaded Terraform content is not excluded"

if rg --quiet 'id-token:[[:space:]]*write|AWS_ACCESS_KEY_ID|aws-actions/configure-aws-credentials' "$workflow"; then
  fail "static Terraform CI must not request AWS authentication"
fi

if rg --quiet 'terraform (plan|apply|destroy)|kubectl|helm|docker push|ecr' "$workflow"; then
  fail "static Terraform CI contains a runtime infrastructure operation"
fi

printf 'DEP-217 acceptance tests passed.\n'
