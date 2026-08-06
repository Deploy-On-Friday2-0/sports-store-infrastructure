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

# Grafana admin login has no external owner, so Terraform generates and owns
# it outright instead of taking it as an input variable. Ephemeral (not a
# state-backed resource) so the password never lands in Terraform state — it
# is regenerated on every plan/apply, rotating the Grafana login each run.
ephemeral "random_password" "grafana_admin" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>?"
}

resource "aws_secretsmanager_secret" "production_observability" {
  name       = "sports-store/production/observability"
  kms_key_id = "alias/aws/secretsmanager"

  tags = {
    Project     = "sports-store"
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_secretsmanager_secret_version" "production_observability" {
  secret_id = aws_secretsmanager_secret.production_observability.id
  secret_string_wo = jsonencode({
    GRAFANA_ADMIN_USER     = "admin"
    GRAFANA_ADMIN_PASSWORD = ephemeral.random_password.grafana_admin.result
    # Same Slack workspace/webhook already used for the config secret
    # (K8sGPT sink) - reused here rather than sourcing a second credential.
    SLACK_WEBHOOK_URL = var.slack_webhook_url
  })
  secret_string_wo_version = var.production_observability_version
}
