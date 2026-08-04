# Sports Store Infrastructure

Terraform source for the Amazon Web Services (AWS) infrastructure that hosts Sports Store. Application code belongs in service repositories; Kubernetes workloads belong in [sports-store-deployments](https://github.com/Deploy-On-Friday2-0/sports-store-deployments).

## Contents

- [What this creates](#what-this-creates)
- [Architecture and layout](#architecture-and-layout)
- [Prerequisites and configuration](#prerequisites-and-configuration)
- [Validate and deploy](#validate-and-deploy)
- [CI/CD and security](#cicd-and-security)
- [Troubleshooting](#troubleshooting)

## What this creates

- A three-Availability-Zone VPC with public and private subnets.
- Amazon EKS (Elastic Kubernetes Service), a managed node group, and the EBS storage driver.
- Amazon ECR (Elastic Container Registry) repositories for deployable components.
- GitHub Actions OpenID Connect (OIDC) roles, avoiding long-lived AWS access keys.
- AWS Secrets Manager values consumed in Kubernetes through External Secrets.
- S3 and CloudFront resources for static frontend delivery.
- Optional ACM certificates and Route 53 records for a custom domain.

## Architecture and layout

`vpc.tf`, `eks.tf`, `ecr.tf`, `iam.tf`, `secrets.tf`, `security.tf`, `frontend.tf`, and `acm.tf` separate resource concerns. `providers.tf` configures Terraform/AWS, `variables.tf` is the input contract, and `outputs.tf` exposes ECR URIs and frontend delivery information. `bootstrap/oidc/` is the separately initialized GitHub OIDC bootstrap module. `kubernetes/storageclasses/` contains the retained EBS storage class; `policies/` contains the load-balancer-controller policy.

Terraform Cloud provides remote state for the root configuration. Do not create a second local state for the same environment.

## Prerequisites and configuration

Install Terraform, configure authorized AWS credentials, and obtain access to the configured Terraform Cloud organization/workspace. Review all inputs before applying.

Common non-secret variables have defaults, including `aws_region=us-east-1`, `environment=prod`, `cluster_name=sports-store-cluster`, Kubernetes `1.30`, and a three-node `t3.medium` managed group (minimum 3, maximum 6). Sensitive required variables include MongoDB, Redis, JWT, Google API, and Slack values; supply them as sensitive Terraform Cloud variables (`TF_VAR_<name>`), never in committed `.tfvars` files.

Custom-domain support is off by default. To enable it, set `enable_custom_domain=true`, `domain_name`, and `route53_zone_id`. Otherwise CloudFront uses its generated domain and default certificate.

## Validate and deploy

```bash
terraform fmt -check -recursive
terraform init
terraform validate
terraform test
terraform plan
terraform apply
```

`plan` previews changes; review it carefully. `apply` changes AWS resources and can incur cost. Useful outputs include:

```bash
terraform output ecr_repository_uris
terraform output cloudfront_domain_name
terraform output acm_certificate_arn
```

Initialize `bootstrap/oidc/` separately when establishing GitHub federation; do not mix its state with the root module.

## CI/CD and security

The `Terraform CI` workflow checks branch naming, formatting, both Terraform modules, Checkov security rules, repository acceptance tests, and reviewer tests. Terraform Cloud/VCS owns infrastructure plans and applies; application publish workflows assume the OIDC-created roles and push to ECR. Argo CD then reconciles Kubernetes state from the deployments repository.

- Treat plans and outputs as potentially sensitive. Never commit state, `.env`, credentials, or secret `.tfvars` files.
- Secrets Manager values are created by Terraform and projected by External Secrets; do not copy values into Kubernetes YAML.
- Review IAM, network, and destruction changes especially carefully. The storage class uses a retain policy to reduce accidental data loss.

## Troubleshooting

- `terraform init` failures commonly indicate Terraform Cloud authentication or backend access issues.
- AWS authorization failures usually mean the selected profile/role lacks the required permissions.
- Custom-domain validation requires the specified Route 53 hosted zone and DNS propagation.
- Run `terraform fmt -recursive` to correct formatting, then repeat validation.
- See [CONTRIBUTING.md](CONTRIBUTING.md) and the [deployment bootstrap guide](https://github.com/Deploy-On-Friday2-0/sports-store-deployments/blob/main/docs/gitops-bootstrap.md).
