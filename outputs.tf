output "ecr_repository_uris" {
  description = "Map of ECR repository names to their registry URIs"
  value       = { for k, v in aws_ecr_repository.microservices : k => v.repository_url }
}

output "frontend_s3_bucket_id" {
  description = "The Name of the S3 bucket hosting static frontend assets"
  value       = aws_s3_bucket.frontend.id
}

output "cloudfront_distribution_id" {
  description = "The ID of the CloudFront distribution for cache invalidation"
  value       = aws_cloudfront_distribution.frontend.id
}

output "cloudfront_domain_name" {
  description = "The domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.frontend.domain_name
}

output "acm_certificate_arn" {
  description = "Validated regional ACM certificate ARN for Helm and ALB Ingress when custom-domain support is enabled; otherwise null"
  value       = var.enable_custom_domain ? aws_acm_certificate_validation.regional[0].certificate_arn : null
}
