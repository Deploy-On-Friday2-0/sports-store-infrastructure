#!/usr/bin/env bash

set -euo pipefail

# Lightweight static acceptance test for DEP-332 (Cluster Autoscaler).
# Runtime provisioning is verified separately against EKS after the bootstrap
# module is applied.

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

ca_dir="bootstrap/cluster-autoscaler"
ca_main="$ca_dir/main.tf"

# Node group scaling bounds must exist in the root module.
assert_contains eks.tf 'min_size     = var.node_min_size' \
  "nodegroup min size must be variable-driven"
assert_contains eks.tf 'max_size     = var.node_max_size' \
  "nodegroup max size must be variable-driven"
assert_contains variables.tf 'variable "node_min_size"' \
  "node_min_size variable missing"
assert_contains variables.tf 'variable "node_max_size"' \
  "node_max_size variable missing"

# Cluster Autoscaler bootstrap module exists and deploys the pinned chart.
assert_contains "$ca_main" 'resource "helm_release" "cluster_autoscaler"' \
  "cluster-autoscaler Helm release is missing"
assert_contains "$ca_main" 'chart            = "cluster-autoscaler"' \
  "cluster-autoscaler chart name is missing"
assert_contains "$ca_main" 'autoDiscovery' \
  "auto-discovery is missing"
assert_contains "$ca_main" 'clusterName = var.cluster_name' \
  "auto-discovery must target the cluster"
assert_contains "$ca_main" 'service_account = "cluster-autoscaler"' \
  "cluster-autoscaler Pod Identity association is missing"

# Cluster Autoscaler needs least-privilege autoscaling IAM.
assert_contains "$ca_main" 'autoscaling:SetDesiredCapacity' \
  "Cluster Autoscaler IAM policy is missing SetDesiredCapacity"
assert_contains "$ca_main" 'autoscaling:TerminateInstanceInAutoScalingGroup' \
  "Cluster Autoscaler IAM policy is missing TerminateInstanceInAutoScalingGroup"
assert_contains "$ca_main" 'eks:DescribeNodegroup' \
  "Cluster Autoscaler IAM policy must describe EKS node groups"

# The chart must be pinned.
assert_contains "$ca_dir/variables.tf" 'variable "cluster_autoscaler_chart_version"' \
  "cluster-autoscaler chart version must be pinned in variables"