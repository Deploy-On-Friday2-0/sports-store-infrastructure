# Sports Store Infrastructure

Terraform source for the AWS infrastructure that hosts the Sports Store platform.

## Planned Scope

- VPC and networking
- Amazon EKS and managed node groups
- Amazon ECR repositories
- IAM roles and GitHub Actions OIDC
- EKS add-ons, including the EBS CSI driver
- Terraform Cloud remote state and VCS-driven runs

Application workloads and Kubernetes deployment manifests belong in `sports-store-deployments`.

## Bootstrap HCP Terraform AWS Authentication

The `bootstrap/oidc` stack creates the AWS OIDC provider and IAM role used by HCP Terraform dynamic provider credentials. Run it once from a workstation with AWS credentials; it uses a local backend and does not depend on HCP Terraform.

Confirm the active AWS identity, then initialize and apply the bootstrap stack:

```bash
aws sts get-caller-identity
terraform -chdir=bootstrap/oidc init
terraform -chdir=bootstrap/oidc plan
terraform -chdir=bootstrap/oidc apply
terraform -chdir=bootstrap/oidc output -raw tfc_aws_run_role_arn
```

To use a named AWS CLI profile, prefix the AWS and Terraform commands with `AWS_PROFILE=<profile>`.

Configure these environment variables in the `sports-store-infrastructure` HCP Terraform workspace:

| Variable | Value |
| --- | --- |
| `TFC_AWS_PROVIDER_AUTH` | `true` |
| `TFC_AWS_RUN_ROLE_ARN` | The value of `tfc_aws_run_role_arn` |

The local `bootstrap/oidc/terraform.tfstate` file contains the ownership record for the bootstrap resources. It is ignored by Git and must be retained securely.

## Supported Outputs

The root module exposes only values needed by deployment and release automation:

| Output | Purpose |
| --- | --- |
| `ecr_repository_uris` | Resolve the registry destination for service image pushes. |
| `frontend_s3_bucket_id` | Identify the bucket that receives frontend build assets. |
| `cloudfront_distribution_id` | Identify the distribution for cache invalidation after frontend releases. |
| `cloudfront_domain_name` | Provide the public frontend endpoint. |
