output "cluster_autoscaler_namespace" {
  value = helm_release.cluster_autoscaler.namespace
}

output "cluster_autoscaler_release_name" {
  value = helm_release.cluster_autoscaler.name
}

output "cluster_autoscaler_status" {
  value = helm_release.cluster_autoscaler.status
}

output "cluster_autoscaler_role_arn" {
  value = aws_iam_role.cluster_autoscaler.arn
}