resource "aws_secretsmanager_secret" "production_config" {
  name       = "sports-store/production/config"
  kms_key_id = "alias/aws/secretsmanager"

  tags = {
    Project     = "sports-store"
    Environment = var.environment
    Terraform   = "true"
  }
}
