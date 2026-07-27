output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

output "ecr_repository_uris" {
  description = "Map of ECR repository names to their registry URIs"
  value       = { for k, v in aws_ecr_repository.microservices : k => v.repository_url }
}

output "eks_cluster_role_arn" {
  description = "ARN of the EKS Cluster control plane IAM role"
  value       = aws_iam_role.eks_cluster.arn
}

output "eks_node_role_arn" {
  description = "ARN of the EKS Worker node IAM role"
  value       = aws_iam_role.eks_node.arn
}

output "eks_node_security_group_id" {
  description = "Security Group ID for EKS worker nodes"
  value       = aws_security_group.eks_nodes.id
}

output "frontend_s3_bucket_id" {
  description = "The Name of the S3 bucket hosting static frontend assets"
  value       = aws_s3_bucket.frontend.id
}

output "cloudfront_distribution_id" {
  description = "The ID of the CloudFront distribution for cache invalidation"
  value       = aws_cloudfront_distribution.frontend.id
}

output "cloudfront_domain_name" {
  description = "The domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.frontend.domain_name
}

output "github_actions_ecr_role_arn" {
  description = "The ARN of the GitHub Actions OIDC ECR push IAM role"
  value       = aws_iam_role.github_actions_ecr.arn
}

output "github_actions_frontend_role_arn" {
  description = "The ARN of the GitHub Actions OIDC Frontend deploy IAM role"
  value       = aws_iam_role.github_actions_frontend.arn
}

output "tfc_actions_role_arn" {
  description = "The ARN of the Terraform Cloud OIDC admin IAM role"
  value       = aws_iam_role.tfc_admin.arn
}
