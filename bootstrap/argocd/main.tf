data "aws_eks_cluster" "target" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "target" {
  name = var.cluster_name
}

resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = "argocd"

    labels = {
      "app.kubernetes.io/name"    = "argocd"
      "app.kubernetes.io/part-of" = "sports-store"
    }
  }
}

locals {
  argocd_ingress = var.argocd_ingress_enabled ? {
    enabled = true
    hosts   = var.argocd_hostname != null ? [var.argocd_hostname] : []
    } : {
    enabled = false
    hosts   = []
  }

  argocd_values = yamlencode({
    crds = {
      install = true
      keep    = true
    }

    controller = {
      resources = {
        requests = {
          cpu    = "100m"
          memory = "256Mi"
        }
        limits = {
          cpu    = "500m"
          memory = "1024Mi"
        }
      }
    }

    server = {
      service = {
        type = "ClusterIP"
      }

      ingress = local.argocd_ingress

      resources = {
        requests = {
          cpu    = "50m"
          memory = "128Mi"
        }
        limits = {
          cpu    = "250m"
          memory = "256Mi"
        }
      }
    }

    repoServer = {
      resources = {
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
        limits = {
          cpu    = "500m"
          memory = "1024Mi"
        }
      }
    }

    applicationSet = {
      resources = {
        requests = {
          cpu    = "50m"
          memory = "64Mi"
        }
        limits = {
          cpu    = "250m"
          memory = "256Mi"
        }
      }
    }

    notifications = {
      resources = {
        requests = {
          cpu    = "25m"
          memory = "64Mi"
        }
        limits = {
          cpu    = "100m"
          memory = "128Mi"
        }
      }
    }

    dex = {
      resources = {
        requests = {
          cpu    = "25m"
          memory = "32Mi"
        }
        limits = {
          cpu    = "100m"
          memory = "128Mi"
        }
      }
    }

    redis = {
      resources = {
        requests = {
          cpu    = "50m"
          memory = "64Mi"
        }
        limits = {
          cpu    = "200m"
          memory = "256Mi"
        }
      }
    }

    redisSecretInit = {
      resources = {
        requests = {
          cpu    = "10m"
          memory = "32Mi"
        }
        limits = {
          cpu    = "100m"
          memory = "64Mi"
        }
      }
    }
  })
}

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = kubernetes_namespace_v1.argocd.metadata[0].name
  repository       = var.argocd_repo_url
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  values           = [local.argocd_values]
  create_namespace = false
  cleanup_on_fail  = true

  depends_on = [kubernetes_namespace_v1.argocd]
}

# The GitOps AppProject and root Application live in the sister deployments
# repo (single source of truth). They are only meaningful once the argo-cd
# CRDs exist, so they are applied after the Helm release installs them.
data "local_file" "sports_store_project" {
  filename = "${var.sports_store_deployments_dir}/projects/sports-store-project.yaml"
}

data "local_file" "sports_store_root_app" {
  filename = "${var.sports_store_deployments_dir}/apps/root-app.yaml"
}

resource "kubernetes_manifest" "sports_store_project" {
  manifest = yamldecode(data.local_file.sports_store_project.content)

  depends_on = [
    helm_release.argocd,
    kubernetes_namespace_v1.argocd,
  ]
}

resource "kubernetes_manifest" "sports_store_root_app" {
  manifest = yamldecode(data.local_file.sports_store_root_app.content)

  depends_on = [
    helm_release.argocd,
    kubernetes_namespace_v1.argocd,
  ]
}

output "argocd_namespace" {
  value = kubernetes_namespace_v1.argocd.metadata[0].name
}

output "argocd_release_name" {
  value = helm_release.argocd.name
}

output "argocd_status" {
  value = helm_release.argocd.status
}
