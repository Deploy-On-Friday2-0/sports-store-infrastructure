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
    }
  }

  variables {
    aws_region                 = "eu-west-1"
    domain_name                = "example.com"
    route53_zone_id            = "Z0123456789EXAMPLE"
    mongo_initdb_root_password = "test-only-mongodb-password"
    jwt_secret_key             = "test-only-jwt-secret"
  }

  assert {
    condition     = aws_acm_certificate.regional.domain_name == var.domain_name
    error_message = "The regional ACM certificate must cover the configured root domain."
  }

  assert {
    condition     = contains(aws_acm_certificate.regional.subject_alternative_names, "*.${var.domain_name}")
    error_message = "The regional ACM certificate must cover the wildcard domain."
  }

  assert {
    condition     = aws_acm_certificate.regional.validation_method == "DNS"
    error_message = "The regional ACM certificate must use DNS validation."
  }

  assert {
    condition     = aws_acm_certificate.global.domain_name == var.domain_name
    error_message = "The global ACM certificate must cover the configured root domain."
  }

  assert {
    condition     = contains(aws_acm_certificate.global.subject_alternative_names, "*.${var.domain_name}")
    error_message = "The global ACM certificate must cover the wildcard domain."
  }

  assert {
    condition     = aws_acm_certificate.global.validation_method == "DNS"
    error_message = "The global ACM certificate must use DNS validation."
  }

  assert {
    condition     = length(regexall("certificate_arn\\s*=\\s*aws_acm_certificate\\.regional\\.arn", file("${path.module}/acm.tf"))) == 1
    error_message = "The regional validation resource must validate the regional certificate."
  }

  assert {
    condition     = length(regexall("certificate_arn\\s*=\\s*aws_acm_certificate\\.global\\.arn", file("${path.module}/acm.tf"))) == 1
    error_message = "The global validation resource must validate the global certificate."
  }

  assert {
    condition     = aws_acm_certificate_validation.regional.timeouts.create == "45m"
    error_message = "The regional certificate validation timeout must accommodate DNS propagation."
  }

  assert {
    condition     = aws_acm_certificate_validation.global.timeouts.create == "45m"
    error_message = "The global certificate validation timeout must accommodate DNS propagation."
  }

  assert {
    condition     = length(regexall("value\\s*=\\s*aws_acm_certificate_validation\\.regional\\.certificate_arn", file("${path.module}/outputs.tf"))) == 1
    error_message = "The acm_certificate_arn output must expose the validated regional certificate ARN."
  }

  assert {
    condition     = contains(aws_cloudfront_distribution.frontend.aliases, var.domain_name)
    error_message = "CloudFront must use the configured custom domain."
  }

  assert {
    condition     = length(regexall("acm_certificate_arn\\s*=\\s*aws_acm_certificate_validation\\.global\\.certificate_arn", file("${path.module}/frontend.tf"))) == 1
    error_message = "CloudFront must use the validated global ACM certificate."
  }

  assert {
    condition     = aws_cloudfront_distribution.frontend.viewer_certificate[0].ssl_support_method == "sni-only"
    error_message = "CloudFront must use SNI-only certificate support."
  }

  assert {
    condition     = aws_cloudfront_distribution.frontend.viewer_certificate[0].minimum_protocol_version == "TLSv1.2_2021"
    error_message = "CloudFront must enforce the TLSv1.2_2021 minimum protocol."
  }

  assert {
    condition     = length(regexall("for_each\\s*=\\s*local\\.acm_validation_domains", file("${path.module}/acm.tf"))) == 1
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
