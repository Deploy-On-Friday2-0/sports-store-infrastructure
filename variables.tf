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

variable "enable_custom_domain" {
  description = "Enable ACM, Route 53 validation, and a custom CloudFront domain."
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "Custom domain name used when enable_custom_domain is true."
  type        = string
  default     = null

  validation {
    condition     = !var.enable_custom_domain || try(length(trimspace(var.domain_name)) > 0, false)
    error_message = "domain_name must be non-null and non-empty when enable_custom_domain is true."
  }
}

variable "route53_zone_id" {
  description = "Route 53 hosted zone ID used when enable_custom_domain is true."
  type        = string
  default     = null

  validation {
    condition     = !var.enable_custom_domain || try(length(trimspace(var.route53_zone_id)) > 0, false)
    error_message = "route53_zone_id must be non-null and non-empty when enable_custom_domain is true."
  }
}

variable "mongo_initdb_root_password" {
  type        = string
  description = "MongoDB production root password"
  sensitive   = true
  ephemeral   = true

  validation {
    condition     = length(var.mongo_initdb_root_password) > 0
    error_message = "The MongoDB production root password must not be empty."
  }
}

variable "jwt_secret_key" {
  type        = string
  description = "Production JWT signing secret"
  sensitive   = true
  ephemeral   = true

  validation {
    condition     = length(var.jwt_secret_key) > 0
    error_message = "The production JWT signing secret must not be empty."
  }
}

variable "production_config_version" {
  type        = number
  description = "Version counter incremented whenever the production secret values rotate"
  default     = 2

  validation {
    condition     = var.production_config_version >= 1 && floor(var.production_config_version) == var.production_config_version
    error_message = "The production config version must be a positive integer."
  }
}

variable "mongodb_replica_set_key" {
  type        = string
  description = "Shared MongoDB ReplicaSet keyfile value (DEP-320); consumed by the ReplicaSet members for mutual authentication"
  sensitive   = true
  ephemeral   = true

  validation {
    condition     = length(var.mongodb_replica_set_key) >= 6 && length(var.mongodb_replica_set_key) <= 1024 && can(regex("^[a-zA-Z0-9+/=]+$", var.mongodb_replica_set_key))
    error_message = "The MongoDB ReplicaSet key must be a valid base64 string between 6 and 1024 characters."
  }
}

variable "redis_password" {
  type        = string
  description = "Production Redis authentication password"
  sensitive   = true
  ephemeral   = true

  validation {
    condition     = length(var.redis_password) > 0
    error_message = "The Redis password must not be empty."
  }
}

variable "google_api_key" {
  type        = string
  description = "Google API Key for K8sGPT AI integration"
  sensitive   = true
  ephemeral   = true

  validation {
    condition     = length(var.google_api_key) > 0
    error_message = "The Google API key must not be empty."
  }
}

variable "slack_webhook_url" {
  type        = string
  description = "Slack Webhook URL for diagnostics and alerting"
  sensitive   = true
  ephemeral   = true

  validation {
    condition     = length(var.slack_webhook_url) > 0
    error_message = "The Slack Webhook URL must not be empty."
  }
}

variable "production_observability_version" {
  type        = number
  description = "Version counter incremented whenever the production observability secret values rotate"
  default     = 1

  validation {
    condition     = var.production_observability_version >= 1 && floor(var.production_observability_version) == var.production_observability_version
    error_message = "The production observability version must be a positive integer."
  }
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

variable "cluster_version" {
  description = "Next Kubernetes minor version for the staged EKS upgrade"
  type        = string
  default     = "1.32"
}

variable "eks_endpoint_public_access" {
  description = "Expose the EKS API publicly only when restricted operator CIDRs are supplied"
  type        = bool
  default     = false

  validation {
    condition     = !var.eks_endpoint_public_access || length(var.eks_endpoint_public_access_cidrs) > 0
    error_message = "eks_endpoint_public_access_cidrs must contain at least one /32 when public EKS API access is enabled."
  }
}

variable "eks_endpoint_public_access_cidrs" {
  description = "Operator IPv4 /32 CIDRs allowed to reach the public EKS API endpoint"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for cidr in var.eks_endpoint_public_access_cidrs :
      can(cidrhost(cidr, 0)) && try(tonumber(split("/", cidr)[1]), 0) == 32
    ])
    error_message = "Every public EKS API CIDR must be a valid IPv4 /32."
  }
}

variable "eks_admin_principal_arn" {
  description = "Optional IAM user or role ARN granted cluster-wide EKS administrator access"
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.eks_admin_principal_arn == null || can(regex("^arn:aws:iam::[0-9]{12}:(user|role)/.+$", var.eks_admin_principal_arn))
    error_message = "eks_admin_principal_arn must be null or a valid IAM user/role ARN."
  }
}

variable "node_instance_type" {
  description = "Worker node instance type"
  type        = string
  default     = "t3.medium"
}

variable "node_min_size" {
  type    = number
  default = 3
}

variable "node_desired_size" {
  type    = number
  default = 4
}

variable "node_max_size" {
  type    = number
  default = 6
}

variable "alb_dns_name" {
  type        = string
  description = "The DNS hostname resolving to the EKS Application Load Balancer (either the raw AWS ELB DNS name, or the custom Route 53 DNS record pointing to it). Defaults to the production ALB DNS name managed by the AWS Load Balancer Controller; override via a Terraform Cloud workspace variable if the ALB is ever recreated."
  default     = "k8s-sportsst-sportsst-87b68165b3-1995243501.us-east-1.elb.amazonaws.com"
}
