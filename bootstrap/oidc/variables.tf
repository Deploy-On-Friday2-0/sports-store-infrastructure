variable "aws_region" {
  type        = string
  description = "AWS region used for the bootstrap operation"
  default     = "us-east-1"
}

variable "tfc_organization" {
  type        = string
  description = "HCP Terraform organization allowed to assume the role"
  default     = "deploy-on-friday"
}

variable "tfc_project" {
  type        = string
  description = "HCP Terraform project allowed to assume the role; an asterisk allows any project"
  default     = "*"
}

variable "tfc_workspace" {
  type        = string
  description = "HCP Terraform workspace allowed to assume the role"
  default     = "sports-store-infrastructure"
}

variable "role_name" {
  type        = string
  description = "Name of the IAM role assumed by HCP Terraform"
  default     = "sports-store-cluster-tfc-admin-role"
}
