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
    MONGODB_REPLICA_SET_KEY    = var.mongodb_replica_set_key
    REDIS_PASSWORD             = var.redis_password
    GOOGLE_API_KEY             = var.google_api_key
    SLACK_WEBHOOK_URL          = var.slack_webhook_url
  })
  secret_string_wo_version = var.production_config_version
}
