output "tfc_aws_run_role_arn" {
  description = "IAM role ARN to configure as TFC_AWS_RUN_ROLE_ARN"
  value       = aws_iam_role.tfc_admin.arn
}
