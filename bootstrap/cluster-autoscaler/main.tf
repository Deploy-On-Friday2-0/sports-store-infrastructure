data "aws_eks_cluster" "target" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "target" {
  name = var.cluster_name
}

#################################################
# IAM (EKS Pod Identity)
#################################################

resource "aws_iam_policy" "cluster_autoscaler" {
  name        = "${var.cluster_name}-cluster-autoscaler"
  description = "Least-privilege autoscaling access for Cluster Autoscaler (DEP-332)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Mutations"
        Effect = "Allow"
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/k8s.io/cluster-autoscaler/enabled"             = "true"
            "aws:ResourceTag/k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
          }
        }
      },
      {
        Sid    = "Reads"
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DescribeTags",
          "ec2:DescribeImages",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:GetInstanceTypesFromInstanceRequirements",
          "eks:DescribeNodegroup"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Project     = "sports-store"
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_iam_role" "cluster_autoscaler" {
  name = "${var.cluster_name}-cluster-autoscaler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })

  tags = {
    Project     = "sports-store"
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  role       = aws_iam_role.cluster_autoscaler.name
  policy_arn = aws_iam_policy.cluster_autoscaler.arn
}

resource "aws_eks_pod_identity_association" "cluster_autoscaler" {
  cluster_name    = var.cluster_name
  namespace       = "kube-system"
  service_account = "cluster-autoscaler"
  role_arn        = aws_iam_role.cluster_autoscaler.arn
}

#################################################
# Cluster Autoscaler
#################################################

locals {
  cluster_autoscaler_values = yamlencode({
    cloudProvider = "aws"
    awsRegion     = var.aws_region

    # Auto-discovery matches the ASG tags EKS places on managed node group
    # Auto Scaling groups: k8s.io/cluster-autoscaler/enabled=true and
    # k8s.io/cluster-autoscaler/<cluster-name>=owned. The node group's
    # min/max size (variables.tf node_min/node_max_size) bound the scale range.
    autoDiscovery = {
      clusterName = var.cluster_name
    }

    image = {
      tag = var.cluster_autoscaler_image_tag
    }

    rbac = {
      serviceAccount = {
        name = "cluster-autoscaler"
      }
    }

    # Single node group spanning AZs; EKS applies the EBS-CSI label to nodes,
    # so balance similar node groups to avoid AZ skew for stateful workloads.
    extraArgs = {
      "balance-similar-node-groups" = "true"
    }

    resources = {
      requests = {
        cpu    = "50m"
        memory = "64Mi"
      }
      limits = {
        cpu    = "250m"
        memory = "512Mi"
      }
    }
  })
}

resource "helm_release" "cluster_autoscaler" {
  name             = "cluster-autoscaler"
  namespace        = "kube-system"
  repository       = var.cluster_autoscaler_repo_url
  chart            = "cluster-autoscaler"
  version          = var.cluster_autoscaler_chart_version
  values           = [local.cluster_autoscaler_values]
  create_namespace = false
  cleanup_on_fail  = true
}
