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


