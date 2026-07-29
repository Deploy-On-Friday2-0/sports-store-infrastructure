#!/usr/bin/env bash

set -euo pipefail

# Lightweight static acceptance test for DEP-291. Runtime provisioning is
# verified separately against EKS after the cluster bootstrap manifest is applied.

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

storage_class="kubernetes/storageclasses/ebs-gp3-retain.yaml"

assert_contains eks.tf 'aws-ebs-csi-driver' \
  "AWS-managed EBS CSI add-on is missing"
assert_contains iam.tf 'AmazonEBSCSIDriverPolicy' \
  "EBS CSI IAM policy is missing"
assert_contains iam.tf 'service_account = "ebs-csi-controller-sa"' \
  "EBS CSI Pod Identity association is missing"

assert_contains "$storage_class" 'apiVersion: storage.k8s.io/v1' \
  "StorageClass API version is incorrect"
assert_contains "$storage_class" 'kind: StorageClass' \
  "StorageClass kind is missing"
assert_contains "$storage_class" 'name: ebs-gp3-retain' \
  "StorageClass name is incorrect"
assert_contains "$storage_class" 'provisioner: ebs.csi.aws.com' \
  "StorageClass CSI provisioner is incorrect"
assert_contains "$storage_class" 'type: gp3' \
  "StorageClass volume type is not gp3"
assert_contains "$storage_class" 'encrypted: "true"' \
  "StorageClass encryption is not enabled"
assert_contains "$storage_class" 'reclaimPolicy: Retain' \
  "StorageClass reclaim policy is not Retain"
assert_contains "$storage_class" 'volumeBindingMode: WaitForFirstConsumer' \
  "StorageClass binding mode is incorrect"
assert_contains "$storage_class" 'allowVolumeExpansion: true' \
  "StorageClass volume expansion is not enabled"

if rg --glob '!tests/dep-291.sh' --fixed-strings 'kubernetes.io/aws-ebs' .; then
  fail "Legacy in-tree AWS EBS provisioner is configured"
fi

if rg --fixed-strings 'storageclass.kubernetes.io/is-default-class' "$storage_class"; then
  fail "ebs-gp3-retain must not be the default StorageClass"
fi

if rg --fixed-strings 'kmsKeyId' "$storage_class"; then
  fail "StorageClass must use the AWS-managed EBS encryption key"
fi

printf 'DEP-291 acceptance tests passed.\n'
