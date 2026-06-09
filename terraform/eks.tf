# eks.tf
# The actual Kubernetes cluster

resource "aws_eks_cluster" "careerlens" {
  name     = var.cluster_name
  version  = "1.31"
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids = concat(
      aws_subnet.public[*].id,
      aws_subnet.private[*].id
    )
    endpoint_public_access  = true
    endpoint_private_access = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]

  tags = {
    Name        = var.cluster_name
    Environment = var.environment
  }
}

# WORKER NODES
resource "aws_eks_node_group" "careerlens" {
  cluster_name    = aws_eks_cluster.careerlens.name
  node_group_name = "workers"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = aws_subnet.private[*].id
  instance_types  = [var.node_type]

  scaling_config {
    desired_size = var.node_count
    min_size     = 1
    max_size     = 2
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node,
    aws_iam_role_policy_attachment.eks_cni,
    aws_iam_role_policy_attachment.ecr_read,
  ]

  tags = {
    Name        = "${var.cluster_name}-workers"
    Environment = var.environment
  }
}

# EBS CSI Driver addon
resource "aws_eks_addon" "ebs_csi" {
  cluster_name = aws_eks_cluster.careerlens.name
  addon_name   = "aws-ebs-csi-driver"

  depends_on = [
    aws_eks_node_group.careerlens
  ]
}
