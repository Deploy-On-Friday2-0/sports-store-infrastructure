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
