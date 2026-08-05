variable "aws_region" {
  type        = string
  description = "AWS region of the target EKS cluster"
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Deployment environment name used for resource tagging"
  default     = "prod"
}

variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster that Cluster Autoscaler discovers node groups in (DEP-332)"
}

variable "cluster_autoscaler_chart_version" {
  type        = string
  description = "Pinned version of the official cluster-autoscaler Helm chart"
  default     = "9.59.0"
}

variable "cluster_autoscaler_image_tag" {
  type        = string
  description = "Cluster Autoscaler image tag; must track the cluster Kubernetes minor version"
  default     = "v1.32.7"
}

variable "cluster_autoscaler_repo_url" {
  type        = string
  description = "Helm repository URL for the official Cluster Autoscaler chart"
  default     = "https://kubernetes.github.io/autoscaler"
}