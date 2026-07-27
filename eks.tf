module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  #################################################
  # Cluster
  #################################################

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  #################################################
  # API Access
  #################################################

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = false

  enable_cluster_creator_admin_permissions = true

  #################################################
  # Core Addons
  #################################################

  cluster_addons = {
    coredns                = {}
    kube-proxy             = {}
    vpc-cni                = {}
    aws-ebs-csi-driver     = {}
    eks-pod-identity-agent = {}
  }

  #################################################
  # Managed Node Groups
  #################################################

  eks_managed_node_groups = {

    default = {

      instance_types = [var.node_instance_type]

      ami_type = "AL2023_x86_64_STANDARD"

      capacity_type = "ON_DEMAND"

      min_size     = var.node_min_size
      desired_size = var.node_desired_size
      max_size     = var.node_max_size

      labels = {
        role = "worker"
      }

      tags = {
        Environment = var.environment
        Project     = "sports-store"
      }
    }
  }

  #################################################
  # Tags
  #################################################

  tags = {
    Environment = var.environment
    Project     = "sports-store"
    Terraform   = "true"
  }
}