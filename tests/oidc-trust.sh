#!/usr/bin/env bash

set -euo pipefail

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

extract_role() {
  local role_name="$1"

  awk -v role="$role_name" '
    $0 == "resource \"aws_iam_role\" \"" role "\" {" { found = 1 }
    found && /^resource / && $0 != "resource \"aws_iam_role\" \"" role "\" {" { exit }
    found { print }
  ' iam.tf
}

subjects() {
  rg --only-matching '"repo:[^"]+"' | tr -d '"' | LC_ALL=C sort
}

ecr_role="$(extract_role github_actions_ecr)"
frontend_role="$(extract_role github_actions_frontend)"

[[ -n "$ecr_role" ]] || fail "GitHub Actions ECR role is missing"
[[ -n "$frontend_role" ]] || fail "GitHub Actions frontend role is missing"

expected_ecr_subjects="$(printf '%s\n' \
  'repo:Deploy-On-Friday2-0@308323292/sports-store-auth-service@1310131112:ref:refs/heads/main' \
  'repo:Deploy-On-Friday2-0@308323292/sports-store-catalog-service@1310134732:ref:refs/heads/main' \
  'repo:Deploy-On-Friday2-0@308323292/sports-store-cart-service@1310133742:ref:refs/heads/main' \
  'repo:Deploy-On-Friday2-0@308323292/sports-store-order-service@1310141707:ref:refs/heads/main' \
  'repo:Deploy-On-Friday2-0@308323292/sports-store-payment-service@1310142804:ref:refs/heads/main' \
  'repo:Deploy-On-Friday2-0@308323292/sports-store-gateway@1310139274:ref:refs/heads/main' | LC_ALL=C sort)"
expected_frontend_subject='repo:Deploy-On-Friday2-0@308323292/sports-store-frontend@1310129795:ref:refs/heads/main'

actual_ecr_subjects="$(printf '%s\n' "$ecr_role" | subjects)"
actual_frontend_subjects="$(printf '%s\n' "$frontend_role" | subjects)"

[[ "$actual_ecr_subjects" == "$expected_ecr_subjects" ]] || \
  fail "ECR trust subjects do not exactly match the six approved immutable main-branch subjects"
[[ "$actual_frontend_subjects" == "$expected_frontend_subject" ]] || \
  fail "frontend trust does not exactly match the approved immutable frontend main-branch subject"

for role in "$ecr_role" "$frontend_role"; do
  printf '%s\n' "$role" | rg --fixed-strings --quiet \
    '"token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"' || \
    fail "GitHub OIDC audience must be sts.amazonaws.com"
  printf '%s\n' "$role" | rg --fixed-strings --quiet \
    'Action = "sts:AssumeRoleWithWebIdentity"' || \
    fail "GitHub OIDC role must use AssumeRoleWithWebIdentity"

  if printf '%s\n' "$role" | rg --quiet 'StringLike|repo:[^"[:space:]]*\*'; then
    fail "GitHub OIDC trust contains a wildcard condition"
  fi
done

if rg --ignore-case --quiet 'repo:deploy-on-friday/' iam.tf; then
  fail "obsolete name-only GitHub organization subject remains in IAM"
fi

all_subjects="$(printf '%s\n%s\n' "$actual_ecr_subjects" "$actual_frontend_subjects")"
subject_count="$(printf '%s\n' "$all_subjects" | sed '/^$/d' | wc -l | tr -d '[:space:]')"
immutable_subject_count="$(printf '%s\n' "$all_subjects" | rg --count \
  '^repo:Deploy-On-Friday2-0@308323292/sports-store-[a-z-]+@[0-9]+:ref:refs/heads/main$')"

[[ "$subject_count" == "7" ]] || fail "expected exactly seven GitHub OIDC subjects"
[[ "$immutable_subject_count" == "7" ]] || \
  fail "every GitHub OIDC subject must include immutable organization and repository IDs"

printf 'GitHub OIDC trust acceptance tests passed.\n'
