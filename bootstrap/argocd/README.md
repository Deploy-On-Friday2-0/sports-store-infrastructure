# Argo CD Bootstrap

A standalone Terraform configuration that installs Argo CD into an existing
EKS cluster using the Helm provider. It is intentionally separate from the
root infrastructure module so the bootstrap can be applied before the main
infrastructure plan and torn down independently during recovery drills.

## Why this exists

The root module manages AWS infrastructure. It does not install Kubernetes
controllers. This bootstrap installs a pinned, resource-limited Argo CD release
matching `sports-store-deployments/bootstrap/argocd.yaml` so the rest of the
GitOps platform can be reconciled after the cluster is online.

## Prerequisites

- An existing EKS cluster reachable from your terminal
- AWS credentials authorized to read the cluster and write Helm releases
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
```

Forward the server locally for verification:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

## Destroy

```bash
terraform destroy -var cluster_name=sports-store-cluster
```

This removes the Helm release and the namespace but leaves the EKS cluster and
its AWS resources untouched.

## Configuration

| Variable | Default | Purpose |
| --- | --- | --- |
| `cluster_name` | - | Name of the target EKS cluster (required) |
| `aws_region` | `us-east-1` | AWS region of the cluster |
| `argocd_chart_version` | `10.2.2` | Pinned argo-cd chart version |
| `argocd_ingress_enabled` | `false` | Expose through an internal ALB |
