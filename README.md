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
