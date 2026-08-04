# EKS Cluster Control Plane IAM Role
resource "aws_iam_role" "eks_cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# EKS Worker Node IAM Role (Least Privilege)
resource "aws_iam_role" "eks_node" {
  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_iam_role_policy_attachment" "eks_node_policy" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  ])

  role       = aws_iam_role.eks_node.name
  policy_arn = each.value
}

# EKS Pod Identity IAM Role (for EBS CSI controller)
resource "aws_iam_role" "ebs_csi" {
  name = "${var.cluster_name}-ebs-csi-role"

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
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_iam_role_policy_attachment" "ebs_csi_policy" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# EKS Pod Identity Association
resource "aws_eks_pod_identity_association" "ebs_csi" {
  cluster_name    = module.eks.cluster_name
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"
  role_arn        = aws_iam_role.ebs_csi.arn
}

# EKS Pod Identity IAM resources for External Secrets Operator
resource "aws_iam_policy" "external_secrets" {
  name        = "${var.cluster_name}-external-secrets-policy"
  description = "Read access to sports-store secrets for External Secrets Operator"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:*:*:secret:sports-store/*"
      }
    ]
  })

  tags = {
    Project     = "sports-store"
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_iam_role" "external_secrets" {
  name = "${var.cluster_name}-external-secrets-role"

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

resource "aws_iam_role_policy_attachment" "external_secrets" {
  role       = aws_iam_role.external_secrets.name
  policy_arn = aws_iam_policy.external_secrets.arn
}

resource "aws_eks_pod_identity_association" "external_secrets" {
  cluster_name    = module.eks.cluster_name
  namespace       = "external-secrets"
  service_account = "external-secrets-sa"
  role_arn        = aws_iam_role.external_secrets.arn
}

# ==========================================
# GitHub Actions OIDC Authentication Setup
# ==========================================

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

# GitHub Actions ECR Push Role
resource "aws_iam_role" "github_actions_ecr" {
  name = "${var.cluster_name}-github-actions-ecr-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              "repo:deploy-on-friday/sports-store-gateway:*",
              "repo:deploy-on-friday/sports-store-auth-service:*",
              "repo:deploy-on-friday/sports-store-catalog-service:*",
              "repo:deploy-on-friday/sports-store-cart-service:*",
              "repo:deploy-on-friday/sports-store-order-service:*",
              "repo:deploy-on-friday/sports-store-payment-service:*"
            ]
          }
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_iam_policy" "github_actions_ecr" {
  name        = "${var.cluster_name}-github-actions-ecr-push"
  description = "Permissions for GitHub Actions to push images to ECR"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:ListImages"
        ]
        Resource = [for repo in aws_ecr_repository.microservices : repo.arn]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions_ecr" {
  role       = aws_iam_role.github_actions_ecr.name
  policy_arn = aws_iam_policy.github_actions_ecr.arn
}

# GitHub Actions Frontend Deploy Role
resource "aws_iam_role" "github_actions_frontend" {
  name = "${var.cluster_name}-github-actions-frontend-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              "repo:deploy-on-friday/sports-store-frontend:*"
            ]
          }
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_iam_policy" "github_actions_frontend" {
  name        = "${var.cluster_name}-github-actions-frontend-deploy"
  description = "Permissions for GitHub Actions to deploy static assets to S3 and invalidate CloudFront cache"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3Upload"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.frontend.arn,
          "${aws_s3_bucket.frontend.arn}/*"
        ]
      },
      {
        Sid    = "CloudFrontInvalidation"
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation"
        ]
        Resource = aws_cloudfront_distribution.frontend.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions_frontend" {
  role       = aws_iam_role.github_actions_frontend.name
  policy_arn = aws_iam_policy.github_actions_frontend.arn
}

# AWS Load Balancer Controller (LBC) IAM Policy
resource "aws_iam_policy" "lbc" {
  name        = "${var.cluster_name}-aws-load-balancer-controller"
  description = "Policy for the AWS Load Balancer Controller inside EKS"
  policy      = file("${path.module}/policies/lbc-iam-policy.json")
}

# AWS Load Balancer Controller IAM Role (EKS Pod Identity)
resource "aws_iam_role" "lbc" {
  name = "${var.cluster_name}-lbc-role"

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
    Environment = var.environment
    Project     = "sports-store"
    Terraform   = "true"
  }
}

# Attach LBC Policy to Role
resource "aws_iam_role_policy_attachment" "lbc" {
  role       = aws_iam_role.lbc.name
  policy_arn = aws_iam_policy.lbc.arn
}

# EKS Pod Identity Association for LBC
resource "aws_eks_pod_identity_association" "lbc" {
  cluster_name    = module.eks.cluster_name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.lbc.arn
}

# ==========================================
# Argo Rollouts ALB Target-Group Weighting (DEP-318)
# ==========================================
# The Argo Rollouts controller shifts traffic during a canary by adjusting the
# ALB target groups behind the Ingress. EKS Pod Identity grants that access to
# the controller ServiceAccount (namespace/SA: argo-rollouts/argo-rollouts) with
# no static credentials and no IAM annotation on the ServiceAccount itself.
# Actions are the three named in DEP-318 AC 1.
resource "aws_iam_policy" "argo_rollouts" {
  name        = "${var.cluster_name}-argo-rollouts-policy"
  description = "ELBv2 target-group access for Argo Rollouts ALB weighting"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ArgoRolloutsTargetGroupWeighting"
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:ModifyTargetGroupAttributes",
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DeregisterTargets"
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

resource "aws_iam_role" "argo_rollouts" {
  name = "${var.cluster_name}-argo-rollouts-role"

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

resource "aws_iam_role_policy_attachment" "argo_rollouts" {
  role       = aws_iam_role.argo_rollouts.name
  policy_arn = aws_iam_policy.argo_rollouts.arn
}

resource "aws_eks_pod_identity_association" "argo_rollouts" {
  cluster_name    = module.eks.cluster_name
  namespace       = "argo-rollouts"
  service_account = "argo-rollouts"
  role_arn        = aws_iam_role.argo_rollouts.arn
}
