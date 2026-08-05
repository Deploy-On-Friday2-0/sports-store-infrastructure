# Cluster Autoscaler Bootstrap

A standalone Terraform configuration that installs the Kubernetes Cluster
Autoscaler (CA) into an existing EKS cluster so the managed node group can
scale between its `min`/`max` bounds automatically (DEP-332). It follows the
same pattern as the Argo CD bootstrap: separate root module, local state,
pinned chart version.

## Why

The `default` managed node group in the root module is sized
`min=3 / desired=4 / max=6` (see `variables.tf`). Those bounds bound the Auto
Scaling Group, but nothing was resizing it when pods went Pending — the DEP-332
manual scale-out to 4 nodes fixed the symptom, Cluster Autoscaler fixes the
cause by watching unschedulable pods and calling `SetDesiredCapacity` itself.

## What this does

1. Creates a least-privilege IAM role (`<cluster>-cluster-autoscaler-role`)
   with an EKS Pod Identity association for the `cluster-autoscaler`
   service account in `kube-system`.
2. Installs the pinned `cluster-autoscaler` Helm chart with auto-discovery
   scoped to the cluster's ASG tags
   (`k8s.io/cluster-autoscaler/enabled`,
   `k8s.io/cluster-autoscaler/<cluster-name>`), which EKS applies to managed
   node group Auto Scaling groups automatically.
3. Pins the CA image tag to the cluster's Kubernetes minor version
   (`v1.32.x` for the 1.32 cluster).

## Prerequisites

- An existing EKS cluster reachable from your terminal
- AWS credentials authorized to read the cluster, create IAM, and write Helm
  releases
- Terraform 1.11+

## Usage

From this directory:

```bash
terraform init
terraform apply -var cluster_name=sports-store-cluster
```

## Verify

```bash
kubectl -n kube-system get deployment cluster-autoscaler
kubectl -n kube-system logs deployment/cluster-autoscaler --tail=50
```

The logs should show the node group discovered and the scale bounds:

```
Found 1 ASGs: [...]
Scale up: 1 node group, ... desired 5
```

## Destroy

```bash
terraform destroy -var cluster_name=sports-store-cluster
```

This removes the Helm release, the IAM role/policy, and the Pod Identity
association, but leaves the EKS cluster untouched.

## Configuration

| Variable | Default | Purpose |
| --- | --- | --- |
| `cluster_name` | - | Name of the target EKS cluster (required) |
| `aws_region` | `us-east-1` | AWS region of the cluster |
| `environment` | `prod` | Tag value used on AWS resources |
| `cluster_autoscaler_chart_version` | `9.59.0` | Pinned cluster-autoscaler chart version |
| `cluster_autoscaler_image_tag` | `v1.32.7` | CA image tag matching the cluster Kubernetes minor |
| `cluster_autoscaler_repo_url` | `https://kubernetes.github.io/autoscaler` | Helm repository for the chart |

> HPA manifests for the workload deployments live in the
> `sports-store-deployments` repo alongside the applications; this module only
> provides the node-level autoscaling half.
