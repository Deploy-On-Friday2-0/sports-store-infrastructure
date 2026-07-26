resource "aws_security_group" "eks_nodes" {
  name        = "${var.cluster_name}-node-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name        = "${var.cluster_name}-node-sg"
    Environment = var.environment
    Terraform   = "true"
  }
}

# Allow nodes to communicate with each other
resource "aws_security_group_rule" "nodes_internal" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.eks_nodes.id
  description              = "Allow nodes to communicate with each other"
}

# Allow control plane to communicate with nodes on HTTPS (443)
resource "aws_security_group_rule" "control_plane_https" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = module.eks.cluster_security_group_id
  description              = "Allow HTTPS from VPC/Control Plane"
}

# Allow control plane to communicate with nodes on Kubelet API (10250)
resource "aws_security_group_rule" "control_plane_kubelet" {
  type                     = "ingress"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = module.eks.cluster_security_group_id
  description              = "Allow Kubelet API from VPC/Control Plane"
}

# Allow outbound traffic
resource "aws_security_group_rule" "nodes_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_nodes.id
  description       = "Allow outbound traffic"
}
