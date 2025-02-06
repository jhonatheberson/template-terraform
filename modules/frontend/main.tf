locals {
  tags               = merge(var.tags_to_append, { Environment = var.environment })
  static_content_dns = "static-content.${var.environment}.${data.aws_route53_zone.dns.name}"
}

resource "random_string" "random_bucket_suffix" {
  length  = 8
  special = false
  upper   = false
  keepers = local.tags
}

resource "aws_s3_bucket" "frontend" {
  bucket = "frontend-${var.environment}-${random_string.random_bucket_suffix.result}"
  tags   = local.tags
}

resource "aws_s3_bucket_public_access_block" "frontend-public-access-block" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "name" {
  bucket       = aws_s3_bucket.frontend.id
  key          = "index.html"
  source       = "${path.module}/index.html"
  content_type = "text/html"
  etag         = filemd5("${path.module}/index.html")

  lifecycle {
    ignore_changes = [etag]
  }
}

resource "aws_s3_bucket_ownership_controls" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "b_acl" {
  bucket     = aws_s3_bucket.frontend.id
  acl        = "private"
  depends_on = [aws_s3_bucket_ownership_controls.frontend]
}


resource "aws_cloudfront_origin_access_control" "default" {
  name                              = "default"
  description                       = "Default Policy"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "random_uuid" "origin_id" {
  keepers = local.tags
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.default.id
    origin_id                = random_uuid.origin_id.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CDN ${var.environment} frontend"
  default_root_object = "index.html"

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.frontend.bucket_domain_name
    prefix          = "cdn_logs/"
  }


  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = random_uuid.origin_id.id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 60
    max_ttl                = 300
  }

  custom_error_response {
    error_caching_min_ttl = 300
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
  }

  custom_error_response {
    error_caching_min_ttl = 300
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "BR"]
    }
  }

  tags = local.tags

  viewer_certificate {
    cloudfront_default_certificate = false

    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"

    acm_certificate_arn = data.aws_acm_certificate.cert.arn
  }

  aliases = [local.static_content_dns]
}

resource "aws_route53_record" "cdn_domain_name" {
  name    = local.static_content_dns
  type    = "A"
  zone_id = data.aws_route53_zone.dns.id

  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_s3_bucket_policy" "cdn-oac-bucket-policy" {
  bucket = aws_s3_bucket.frontend.id
  policy = data.aws_iam_policy_document.s3_bucket_policy.json
}

output "frontend_url" {
  value = "https://${aws_route53_record.cdn_domain_name.fqdn}/"
}

output "cdn_distribution_id" {
  value = aws_cloudfront_distribution.s3_distribution.id
}

output "bucket_name" {
  value = aws_s3_bucket.frontend.bucket
}
