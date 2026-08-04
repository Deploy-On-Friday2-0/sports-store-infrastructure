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

assert_contains variables.tf 'default     = "1.32"' \
  "the staged EKS target must be Kubernetes 1.32"
assert_contains variables.tf 'default     = false' \
  "public EKS API access must remain disabled by default"
assert_contains variables.tf 'try(tonumber(split("/", cidr)[1]), 0) == 32' \
  "public EKS API CIDRs must be restricted to individual IPv4 addresses"
assert_contains eks.tf 'cluster_endpoint_public_access       = var.eks_endpoint_public_access' \
  "EKS public endpoint access is not controlled by the approved variable"
assert_contains eks.tf 'cluster_endpoint_public_access_cidrs = var.eks_endpoint_public_access_cidrs' \
  "EKS public endpoint CIDRs are not explicitly restricted"
assert_contains eks.tf 'policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"' \
  "the operator EKS access entry is missing its cluster administrator policy"

if rg --fixed-strings --quiet '0.0.0.0/0' eks.tf variables.tf; then
  fail "EKS API access must never be open to the internet"
fi

printf 'EKS staged-upgrade and operator-access acceptance tests passed.\n'
