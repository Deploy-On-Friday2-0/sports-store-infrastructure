terraform {
  required_version = ">= 1.11.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "kubernetes" {
  host                     = data.aws_eks_cluster.target.endpoint
  cluster_ca_certificate   = base64decode(data.aws_eks_cluster.target.certificate_authority[0].data)
  token                    = data.aws_eks_cluster_auth.target.token
}

provider "helm" {
  kubernetes {
    host                     = data.aws_eks_cluster.target.endpoint
    cluster_ca_certificate   = base64decode(data.aws_eks_cluster.target.certificate_authority[0].data)
    token                    = data.aws_eks_cluster_auth.target.token
  }
}
