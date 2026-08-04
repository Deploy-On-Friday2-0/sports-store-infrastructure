resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "10.2.2"
  namespace        = "argocd"
  create_namespace = true

  values = [
    <<-EOT
    crds:
      install: true
      keep: true

    controller:
      resources:
        requests:
          cpu: 100m
          memory: 256Mi
        limits:
          cpu: 500m
          memory: 512Mi

    server:
      service:
        type: ClusterIP
      ingress:
        enabled: false
      resources:
        requests:
          cpu: 50m
          memory: 128Mi
        limits:
          cpu: 250m
          memory: 256Mi

    repoServer:
      resources:
        requests:
          cpu: 100m
          memory: 128Mi
        limits:
          cpu: 500m
          memory: 512Mi

    applicationSet:
      resources:
        requests:
          cpu: 50m
          memory: 64Mi
        limits:
          cpu: 250m
          memory: 256Mi

    notifications:
      resources:
        requests:
          cpu: 25m
          memory: 64Mi
        limits:
          cpu: 100m
          memory: 128Mi

    dex:
      resources:
        requests:
          cpu: 25m
          memory: 32Mi
        limits:
          cpu: 100m
          memory: 128Mi

    redis:
      resources:
        requests:
          cpu: 50m
          memory: 64Mi
        limits:
          cpu: 200m
          memory: 256Mi

    redisSecretInit:
      resources:
        requests:
          cpu: 10m
          memory: 32Mi
        limits:
          cpu: 100m
          memory: 64Mi
    EOT
  ]
}

resource "terraform_data" "argocd_bootstrap" {
  depends_on = [helm_release.argocd]

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}; kubectl apply -f ../sports-store-deployments/projects/sports-store-project.yaml; kubectl apply -f ../sports-store-deployments/apps/root-app.yaml"
  }
}
