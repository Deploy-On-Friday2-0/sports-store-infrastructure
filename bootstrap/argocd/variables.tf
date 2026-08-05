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

variable "argocd_ingress_enabled" {
  type        = bool
  description = "Expose the Argo CD server through an Ingress (internal ALB via the AWS Load Balancer Controller). Disabled until DEP-240 is verified."
  default     = false
}

variable "argocd_hostname" {
  type        = string
  description = "Internal DNS hostname served by the Argo CD server Ingress. Required only when argocd_ingress_enabled is true."
  default     = null
}

variable "sports_store_deployments_dir" {
  type        = string
  description = "Path to the sibling sports-store-deployments checkout that owns the AppProject and root Application manifests. Defaults to the adjacent repo relative to this module."
  default     = "../../../sports-store-deployments"
}
