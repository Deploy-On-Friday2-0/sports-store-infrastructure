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

## Supported Outputs

The root module exposes only values needed by deployment and release automation:

| Output | Purpose |
| --- | --- |
| `ecr_repository_uris` | Resolve the registry destination for service image pushes. |
| `frontend_s3_bucket_id` | Identify the bucket that receives frontend build assets. |
| `cloudfront_distribution_id` | Identify the distribution for cache invalidation after frontend releases. |
| `cloudfront_domain_name` | Provide the public frontend endpoint. |
