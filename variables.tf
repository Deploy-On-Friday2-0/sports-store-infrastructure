variable "aws_region" {
  type        = string
  description = "AWS region to deploy resources"
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Deployment environment name"
  default     = "prod"
}

variable "vpc_name" {
  type        = string
  description = "The name of the VPC"
  default     = "sports-store-vpc"
}

variable "vpc_cidr" {
  type        = string
  description = "The CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "vpc_azs" {
  type        = list(string)
  description = "Availability Zones to span"
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "vpc_private_subnets" {
  type        = list(string)
  description = "List of private subnet CIDRs"
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "vpc_public_subnets" {
  type        = list(string)
  description = "List of public subnet CIDRs"
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster for resource tagging"
  default     = "sports-store-cluster"
}

variable "ecr_repositories" {
  type        = list(string)
  description = "List of ECR repository names to create"
  default = [
    "gateway",
    "auth-service",
    "catalog-service",
    "cart-service",
    "order-service",
    "payment-service"
  ]
}

variable "alb_dns_name" {
  type        = string
  description = "The DNS hostname resolving to the EKS Application Load Balancer (either the raw AWS ELB DNS name, or the custom Route 53 DNS record pointing to it)"
  default     = "alb.sports-store.com"
}
