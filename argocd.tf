resource "terraform_data" "argocd_bootstrap" {
  # Depends on EKS cluster module completion
  depends_on = [module.eks]

  triggers_replace = [
    module.eks.cluster_name,
    module.eks.cluster_endpoint
  ]

  provisioner "local-exec" {
    command = "python3 bootstrap_argocd.py ${module.eks.cluster_name} ${var.aws_region}"
  }
}
