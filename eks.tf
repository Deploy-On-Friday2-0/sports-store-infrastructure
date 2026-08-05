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

  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access       = var.eks_endpoint_public_access
  cluster_endpoint_public_access_cidrs = var.eks_endpoint_public_access_cidrs

  enable_cluster_creator_admin_permissions = true

  access_entries = var.eks_admin_principal_arn == null ? {} : {
    operator = {
      principal_arn = var.eks_admin_principal_arn

      policy_associations = {
        cluster_admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  #################################################
  # Core Addons
  #################################################

  cluster_addons = {
    coredns    = {}
    kube-proxy = {}

    # Provisioned before the node group so pod networking and Pod Identity
    # credentials are available the moment nodes join.
    vpc-cni                = { before_compute = true }
    eks-pod-identity-agent = { before_compute = true }

    # The controller reaches ACTIVE only when its pods are healthy. Force
    # OVERWRITE so the add-on can take ownership of any pre-existing/self-managed
    # CSI objects (a common cause of the add-on hanging in CREATING), and pull
    # the latest driver build. Credentials come from the Pod Identity
    # association in iam.tf, with the node-role policy below as a fallback for
    # the Pod-Identity-agent startup race.
    aws-ebs-csi-driver = {
      most_recent                 = true
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }

    # Serves pod/node CPU & memory to the metrics API so the sports-store
    # Helm chart's per-service HorizontalPodAutoscalers have something to
    # read; without it they sit stuck reporting an "unknown" current metric.
    metrics-server = {}
  }

  #################################################
  # Managed Node Groups
  #################################################

  eks_managed_node_groups = {

    default = {

      instance_types = [var.node_instance_type]

      ami_type = "AL2023_x86_64_STANDARD"

      # Give worker nodes the EBS CSI permissions directly so the
      # ebs-csi-controller can fall back to node-instance credentials if the
      # Pod Identity association isn't ready when the pod starts (DEP-320 race).
      # Attached to the module-managed node role in place, so no node
      # replacement — unlike swapping node_role_arn, which is force-new.
      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }

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
