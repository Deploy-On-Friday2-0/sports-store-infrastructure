variable "aws_region" {
  type        = string
  description = "AWS region of the target EKS cluster"
  default     = "us-east-1"
}

variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster to bootstrap Argo CD into"
}

variable "argocd_chart_version" {
  type        = string
  description = "Pinned version of the official argo-cd Helm chart"
  default     = "10.2.2"
}

variable "argocd_repo_url" {
  type        = string
  description = "Helm repository URL for the official Argo CD chart"
  default     = "https://argoproj.github.io/argo-helm"
}

variable "argocd_admin_password_hash" {
  type        = string
  description = "bcrypt hash of the Argo CD admin password. Use `htpasswd` or argocd's generator"
  sensitive   = true
  default     = null
}

variable "argocd_ingress_enabled" {
  type        = bool
  description = "Expose Argo CD server through an internal ALB. Requires hostname, ACM cert, and ALB controller."
  default     = false
}

variable "argocd_hostname" {
  type        = string
  description = "Internal DNS hostname for Argo CD server ingress"
  default     = null
}

variable "argocd_acm_certificate_arn" {
  type        = string
  description = "ACM certificate ARN for the Argo CD ingress hostname"
  default     = null
}

variable "argocd_alb_scheme" {
  type        = string
  description = "ALB scheme for the Argo CD server ingress"
  default     = "internal"
}

variable "argocd_alb_subnets" {
  type        = list(string)
  description = "Private subnet IDs for the internal ALB"
  default     = []
}

variable "argocd_alb_security_groups" {
  type        = list(string)
  description = "Security group IDs for the internal ALB"
  default     = []
}

variable "argocd_load_balancer_controller_role_arn" {
  type        = string
  description = "IRSA role ARN assumed by the AWS Load Balancer Controller when ingress is enabled"
  default     = null
}
