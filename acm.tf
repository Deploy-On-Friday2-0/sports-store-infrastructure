resource "aws_acm_certificate" "regional" {
  count = var.enable_custom_domain ? 1 : 0

  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Environment = var.environment
    Project     = "sports-store"
    Terraform   = "true"
  }
}

resource "aws_acm_certificate" "global" {
  count    = var.enable_custom_domain ? 1 : 0
  provider = aws.us_east_1

  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Environment = var.environment
    Project     = "sports-store"
    Terraform   = "true"
  }
}

locals {
  acm_domain_validation_options = var.enable_custom_domain ? merge(
    {
      for option in aws_acm_certificate.regional[0].domain_validation_options :
      option.resource_record_name => option
    },
    {
      for option in aws_acm_certificate.global[0].domain_validation_options :
      option.resource_record_name => option
    }
  ) : {}
}

resource "aws_route53_record" "acm_validation" {
  for_each = local.acm_domain_validation_options

  allow_overwrite = true
  zone_id         = var.route53_zone_id
  name            = each.value.resource_record_name
  type            = each.value.resource_record_type
  ttl             = 60
  records         = [each.value.resource_record_value]
}

resource "aws_acm_certificate_validation" "regional" {
  count = var.enable_custom_domain ? 1 : 0

  certificate_arn         = aws_acm_certificate.regional[0].arn
  validation_record_fqdns = [for record in aws_route53_record.acm_validation : record.fqdn]

  timeouts {
    create = "45m"
  }
}

resource "aws_acm_certificate_validation" "global" {
  count    = var.enable_custom_domain ? 1 : 0
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.global[0].arn
  validation_record_fqdns = [for record in aws_route53_record.acm_validation : record.fqdn]

  timeouts {
    create = "45m"
  }
}
