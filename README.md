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

## Frontend Domain and TLS

Custom-domain support is disabled by default. In this mode, Terraform creates no
custom ACM certificates or Route 53 validation records, and the frontend remains
available over HTTPS at the generated `cloudfront_domain_name` using the default
CloudFront certificate.

To enable a custom domain later, configure these Terraform variables:

| Variable | Purpose |
| --- | --- |
| `enable_custom_domain` | Set to `true` to enable ACM, Route 53 validation, and the CloudFront alias. Defaults to `false`. |
| `domain_name` | Root domain covered by the ACM certificate and its wildcard alternative. Required only when custom-domain support is enabled. |
| `route53_zone_id` | Route 53 hosted zone ID containing the root domain. Required only when custom-domain support is enabled. |

When enabled, Terraform requests regional and `us-east-1` ACM certificates for
the root domain and its wildcard, creates DNS validation records in Route 53,
waits for certificate issuance, and configures the custom CloudFront alias.

After a successful apply, retrieve the validated certificate ARN with:

```bash
terraform output acm_certificate_arn
```

## Supported Outputs

The root module exposes only values needed by deployment and release automation:

| Output | Purpose |
| --- | --- |
| `ecr_repository_uris` | Resolve the registry destination for service image pushes. |
| `frontend_s3_bucket_id` | Identify the bucket that receives frontend build assets. |
| `cloudfront_distribution_id` | Identify the distribution for cache invalidation after frontend releases. |
| `cloudfront_domain_name` | Provide the public frontend endpoint. |
| `acm_certificate_arn` | Configure Helm values and the AWS ALB Ingress certificate annotation; returns `null` when custom-domain support is disabled. |
