resource "aws_secretsmanager_secret" "production_config" {
  name       = "sports-store/production/config"
  kms_key_id = "alias/aws/secretsmanager"

  tags = {
    Project     = "sports-store"
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_secretsmanager_secret_version" "production_config" {
  secret_id = aws_secretsmanager_secret.production_config.id
  secret_string_wo = jsonencode({
    MONGO_INITDB_ROOT_PASSWORD = var.mongo_initdb_root_password
    JWT_SECRET_KEY             = var.jwt_secret_key
  })
  secret_string_wo_version = var.production_config_version
}
