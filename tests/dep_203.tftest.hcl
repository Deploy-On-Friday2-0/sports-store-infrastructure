mock_provider "aws" {
  mock_resource "aws_acm_certificate" {
    defaults = {
      arn = "arn:aws:acm:eu-west-1:123456789012:certificate/regional-test"
      domain_validation_options = [
        {
          domain_name           = "example.com"
          resource_record_name  = "_validation.example.com"
          resource_record_type  = "CNAME"
          resource_record_value = "_token.acm-validations.aws"
        },
        {
          domain_name           = "*.example.com"
          resource_record_name  = "_validation.example.com"
          resource_record_type  = "CNAME"
          resource_record_value = "_token.acm-validations.aws"
        }
      ]
    }
  }
}

mock_provider "aws" {
  alias = "us_east_1"

  mock_resource "aws_acm_certificate" {
    defaults = {
      arn = "arn:aws:acm:us-east-1:123456789012:certificate/global-test"
      domain_validation_options = [
        {
          domain_name           = "example.com"
          resource_record_name  = "_validation.example.com"
          resource_record_type  = "CNAME"
          resource_record_value = "_token.acm-validations.aws"
        },
        {
          domain_name           = "*.example.com"
          resource_record_name  = "_validation.example.com"
          resource_record_type  = "CNAME"
          resource_record_value = "_token.acm-validations.aws"
        }
      ]
    }
  }
}

run "dep_203_acm_and_cloudfront_configuration" {
  command = plan

  override_module {
    target = module.vpc
    outputs = {
      vpc_id          = "vpc-0123456789abcdef0"
      private_subnets = ["subnet-0123456789abcdef0"]
    }
  }

  override_module {
    target = module.eks
    outputs = {
      cluster_security_group_id = "sg-0123456789abcdef0"
      cluster_name              = "sports-store-test"
    }
  }

  variables {
    aws_region                 = "eu-west-1"
    domain_name                = "example.com"
    route53_zone_id            = "Z0123456789EXAMPLE"
    mongo_initdb_root_password = "test-only-mongodb-password"
    jwt_secret_key             = "test-only-jwt-secret"
    mongodb_replica_set_key    = "dGVzdC1vbmx5LXJlcGxpY2Eta2V5"
    redis_password             = "test-only-redis-password"
    google_api_key             = "test-only-google-api-key"
    slack_webhook_url          = "https://example.invalid/test-only-webhook"
  }

  assert {
    condition     = strcontains(file("${path.module}/acm.tf"), "resource \"aws_acm_certificate\" \"regional\"")
    error_message = "The regional ACM certificate must cover the configured root domain."
  }

  assert {
    condition     = length(regexall("subject_alternative_names[[:space:]]*=[[:space:]]*[^\\n]+var\\.domain_name", file("${path.module}/acm.tf"))) == 2
    error_message = "The regional ACM certificate must cover the wildcard domain."
  }

  assert {
    condition     = length(regexall("validation_method[[:space:]]*=", file("${path.module}/acm.tf"))) == 2
    error_message = "The regional ACM certificate must use DNS validation."
  }

  assert {
    condition     = strcontains(file("${path.module}/acm.tf"), "resource \"aws_acm_certificate\" \"global\"")
    error_message = "The global ACM certificate must cover the configured root domain."
  }

  assert {
    condition     = length(regexall("count\\s*=\\s*var\\.enable_custom_domain\\s*\\?\\s*1\\s*:\\s*0", file("${path.module}/acm.tf"))) == 4
    error_message = "ACM resources must remain conditional on custom-domain enablement."
  }

  assert {
    condition     = length(regexall("certificate_arn\\s*=\\s*aws_acm_certificate\\.regional\\[0\\]\\.arn", file("${path.module}/acm.tf"))) == 1
    error_message = "The regional validation resource must validate the regional certificate."
  }

  assert {
    condition     = length(regexall("certificate_arn\\s*=\\s*aws_acm_certificate\\.global\\[0\\]\\.arn", file("${path.module}/acm.tf"))) == 1
    error_message = "The global validation resource must validate the global certificate."
  }

  assert {
    condition     = length(regexall("create[[:space:]]*=[^\\n]+45m", file("${path.module}/acm.tf"))) == 2
    error_message = "The regional certificate validation timeout must accommodate DNS propagation."
  }

  assert {
    condition     = length(regexall("value\\s*=.*aws_acm_certificate_validation\\.regional\\[0\\]\\.certificate_arn", file("${path.module}/outputs.tf"))) == 1
    error_message = "The acm_certificate_arn output must expose the validated regional certificate ARN."
  }

  assert {
    condition     = length(aws_cloudfront_distribution.frontend.aliases) == 0
    error_message = "CloudFront aliases must be empty when custom-domain support is disabled."
  }

  assert {
    condition     = length(regexall("acm_certificate_arn\\s*=.*aws_acm_certificate_validation\\.global\\[0\\]\\.certificate_arn", file("${path.module}/frontend.tf"))) == 1
    error_message = "CloudFront must use the validated global ACM certificate."
  }

  assert {
    condition     = aws_cloudfront_distribution.frontend.viewer_certificate[0].cloudfront_default_certificate
    error_message = "CloudFront must use its default certificate when custom-domain support is disabled."
  }

  assert {
    condition     = length(regexall("minimum_protocol_version[[:space:]]*=.*TLSv1\\.2_2021.*null", file("${path.module}/frontend.tf"))) == 1
    error_message = "CloudFront must enforce the TLSv1.2_2021 minimum protocol."
  }

  assert {
    condition     = length(regexall("for_each\\s*=\\s*local\\.acm_domain_validation_options", file("${path.module}/acm.tf"))) == 1
    error_message = "Route53 validation records must be created dynamically from the combined validation options."
  }

  assert {
    condition     = length(regexall("provider\\s*=\\s*aws\\.us_east_1", file("${path.module}/acm.tf"))) == 2
    error_message = "The global certificate and its validation resource must use the us-east-1 provider."
  }

  assert {
    condition     = length(regexall("create_before_destroy\\s*=\\s*true", file("${path.module}/acm.tf"))) == 2
    error_message = "Both ACM certificates must be replaced without service interruption."
  }
}
