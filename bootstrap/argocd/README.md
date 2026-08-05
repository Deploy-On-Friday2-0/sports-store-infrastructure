# Argo CD Bootstrap

A standalone Terraform configuration that installs Argo CD into an existing
EKS cluster and completes the GitOps bootstrap. It is intentionally separate
from the root infrastructure module so the bootstrap can be applied before the
main infrastructure plan and torn down independently during recovery drills.

## What this does

1. Creates the `argocd` namespace.
2. Installs a pinned, resource-limited `argo-cd` Helm release (chart `10.2.2`)
   configured to match `sports-store-deployments/bootstrap/argocd.yaml`.
3. Applies the `sports-store-project` AppProject and the
   `sports-store-root` root Application from the sibling
   `sports-store-deployments` repo, so Argo CD immediately reconciles the rest
   of the platform.

> The AppProject and root Application are owned by `sports-store-deployments`.
> This module only *applies* them; edit their source files there.

## Prerequisites

- An existing EKS cluster reachable from your terminal
- AWS credentials authorized to read the cluster and write Helm releases
- The sibling `sports-store-deployments` checkout present (default path
  `../../sports-store-deployments`). Override with `-var
  sports_store_deployments_dir=/path/to/sports-store-deployments`.
- Terraform 1.11+

## Usage

From this directory:

```bash
terraform init
terraform validate
terraform apply
```

Pass the cluster name explicitly:

```bash
terraform apply -var cluster_name=sports-store-cluster
```

## Verify

```bash
argo login --grpc-web localhost:8080
kubectl -n argocd get pods,deployments
kubectl -n argocd get applications
```

Forward the server locally for verification:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

## Destroy

```bash
terraform destroy -var cluster_name=sports-store-cluster
```

This removes the Helm release, the namespace, and the applied GitOps
manifests, but leaves the EKS cluster and its AWS resources untouched.

## Configuration

| Variable | Default | Purpose |
| --- | --- | --- |
| `cluster_name` | - | Name of the target EKS cluster (required) |
| `aws_region` | `us-east-1` | AWS region of the cluster |
| `argocd_chart_version` | `10.2.2` | Pinned argo-cd chart version |
| `argocd_repo_url` | `https://argoproj.github.io/argo-helm` | Helm repository for the chart |
| `argocd_ingress_enabled` | `false` | Expose the Argo CD server via an internal ALB Ingress (DEP-240; disabled until verified). Requires `argocd_hostname`. |
| `argocd_hostname` | - | Internal DNS hostname for the Ingress |
| `sports_store_deployments_dir` | `../../sports-store-deployments` | Path to the sibling deployments repo that owns the AppProject/root Application |
