# Sports Store Infrastructure

Terraform source for the Amazon Web Services (AWS) infrastructure that hosts Sports Store. Application code belongs in service repositories; Kubernetes workloads belong in [sports-store-deployments](https://github.com/Deploy-On-Friday2-0/sports-store-deployments).

## Contents

- [What this creates](#what-this-creates)
- [Architecture and layout](#architecture-and-layout)
- [Prerequisites and configuration](#prerequisites-and-configuration)
- [Validate and deploy](#validate-and-deploy)
- [Staged EKS upgrades](#staged-eks-upgrades)
- [CI/CD and security](#cicd-and-security)
- [Troubleshooting](#troubleshooting)

## What this creates

- A three-Availability-Zone VPC with public and private subnets.
- Amazon EKS (Elastic Kubernetes Service), a managed node group, and the EBS storage driver.
- Cluster Autoscaler (via `bootstrap/cluster-autoscaler/`) so the node group scales automatically between its minimum and maximum size when pods go Pending (DEP-332).
- Amazon ECR (Elastic Container Registry) repositories for deployable components.
- GitHub Actions OpenID Connect (OIDC) roles, avoiding long-lived AWS access keys.
- AWS Secrets Manager values consumed in Kubernetes through External Secrets.
- S3 and CloudFront resources for static frontend delivery.
- Optional ACM certificates and Route 53 records for a custom domain.

## Architecture and layout

`vpc.tf`, `eks.tf`, `ecr.tf`, `iam.tf`, `secrets.tf`, `security.tf`, `frontend.tf`, and `acm.tf` separate resource concerns. `providers.tf` configures Terraform/AWS, `variables.tf` is the input contract, and `outputs.tf` exposes ECR URIs and frontend delivery information. `bootstrap/oidc/` is the separately initialized GitHub OIDC bootstrap module, `bootstrap/argocd/` installs Argo CD, and `bootstrap/cluster-autoscaler/` installs Cluster Autoscaler (DEP-332). `kubernetes/storageclasses/` contains the retained EBS storage class; `policies/` contains the load-balancer-controller policy.

Terraform Cloud provides remote state for the root configuration. Do not create a second local state for the same environment.

## Prerequisites and configuration

Install Terraform, configure authorized AWS credentials, and obtain access to the configured Terraform Cloud organization/workspace. Review all inputs before applying.

Common non-secret variables have defaults, including `aws_region=us-east-1`, `environment=prod`, `cluster_name=sports-store-cluster`, the next Kubernetes target `1.32`, and a three-node `t3.medium` managed group (minimum 3, maximum 6). Sensitive required variables include MongoDB, Redis, JWT, Google API, and Slack values; supply them as sensitive Terraform Cloud variables (`TF_VAR_<name>`), never in committed `.tfvars` files.

The EKS API remains private by default. For temporary operator access, set `eks_endpoint_public_access=true`, provide only operator IPv4 `/32` values in `eks_endpoint_public_access_cidrs`, and set `eks_admin_principal_arn` to the approved IAM user or role. Never use `0.0.0.0/0`; remove or rotate the CIDR when the operator address changes.

Custom-domain support is off by default. To enable it, set `enable_custom_domain=true`, `domain_name`, and `route53_zone_id`. Otherwise CloudFront uses its generated domain and default certificate.

## Validate and deploy

The root configuration is applied first and then each `bootstrap/*` root in
order. A full cluster bring-up (new cluster or rebuild after `destroy`)
follows these steps:

1. **Root infrastructure** (from this directory):
   ```bash
   terraform fmt -check -recursive
   terraform init
   terraform validate
   terraform test
   terraform plan
   terraform apply
   ```
   This creates the VPC, EKS cluster and managed node group, EBS CSI driver,
   OIDC roles, frontend delivery, and the managed Secrets Manager values.
   `plan` previews changes; review it carefully. `apply` changes AWS resources
   and can incur cost.

2. **Cluster Autoscaler** (separate Terraform root with its own state):
   ```bash
   cd bootstrap/cluster-autoscaler
   terraform init
   terraform apply -var cluster_name=sports-store-cluster
   ```
   Autoscaling is not reinstalled by the root `apply`, so this step is
   required after every rebuild. If skipped, the node group stays fixed at its
   minimum size and Pending pods are not scaled for.

3. **Argo CD + GitOps bootstrap** (separate Terraform root):
   ```bash
   cd bootstrap/argocd
   terraform apply -var cluster_name=sports-store-cluster
   ```
   This installs the pinned Argo CD Helm release, applies the
   `ebs-gp3-retain` StorageClass, and registers the AppProject and root
   Application from `sports-store-deployments`. See
   [bootstrap/argocd/README.md](bootstrap/argocd/README.md).

4. **Deployment-side bootstrap** (from a checkout of `sports-store-deployments`):
   ```bash
   pwsh scripts/bootstrap-gitops.ps1
   ```
   The script applies the platform namespaces and the remaining Argo CD
   Applications (controllers, monitoring, Kubecost). Argo CD then reconciles
   the `sports-store` workloads itself. See
   [gitops-bootstrap.md](https://github.com/Deploy-On-Friday2-0/sports-store-deployments/blob/main/docs/gitops-bootstrap.md).

5. **Verify**:
   ```bash
   kubectl -n argocd get applications        # sports-store-root, sports-store-production Healthy
   kubectl -n sports-store get pods          # mongodb x3, redis x3, all services Running
   ```

6. **Close temporary access**: if `eks_endpoint_public_access` was enabled to
   allow the bootstrap, remove the operator CIDR (set
   `eks_endpoint_public_access=false`) and re-apply the root configuration.

Useful root outputs include:

```bash
terraform output ecr_repository_uris
terraform output cloudfront_domain_name
terraform output acm_certificate_arn
```

Initialize `bootstrap/oidc/` separately when establishing GitHub federation;
do not mix its state with the root module.

> Canary rollouts (catalog, order) run Prometheus analysis that fails on empty
> metrics. Run the k6 load test
> (`load-testing/k6/high-concurrency.js` in `sports-store-deployments`) during
> any rollout or demo so the analysis gates have traffic to evaluate.

## Staged EKS upgrades

The live EKS cluster is on Kubernetes 1.31 and this configuration declares 1.32 as the next reviewed target. EKS upgrades must proceed one minor version at a time: 1.31 -> 1.32 -> 1.33 -> 1.34. Plan, review, apply, and verify each step separately. Version 1.34 is the target because it remains in EKS standard support and avoids extended-support control-plane charges.

Before every step, check EKS Upgrade Insights and review compatibility and version changes for the control plane, managed node group, and all EKS add-ons, including the Pod Identity Agent, VPC CNI, and EBS CSI driver. Inspect the complete Terraform plan for unexpected destruction or replacement before approval. Do not run `terraform apply` as part of source-only maintenance or validation work.

## CI/CD and security

The `Terraform CI` workflow checks branch naming, formatting, all Terraform modules (infrastructure and each `bootstrap/*` root), Checkov security rules, repository acceptance tests, and reviewer tests. Terraform Cloud/VCS owns infrastructure plans and applies; application publish workflows assume the OIDC-created roles and push to ECR. Argo CD then reconciles Kubernetes state from the deployments repository.

- Treat plans and outputs as potentially sensitive. Never commit state, `.env`, credentials, or secret `.tfvars` files.
- Secrets Manager values are created by Terraform and projected by External Secrets; do not copy values into Kubernetes YAML.
- Review IAM, network, and destruction changes especially carefully. The storage class uses a retain policy to reduce accidental data loss.

## Troubleshooting

- `terraform init` failures commonly indicate Terraform Cloud authentication or backend access issues.
- AWS authorization failures usually mean the selected profile/role lacks the required permissions.
- Custom-domain validation requires the specified Route 53 hosted zone and DNS propagation.
- Run `terraform fmt -recursive` to correct formatting, then repeat validation.
- See [CONTRIBUTING.md](CONTRIBUTING.md) and the [deployment bootstrap guide](https://github.com/Deploy-On-Friday2-0/sports-store-deployments/blob/main/docs/gitops-bootstrap.md).
