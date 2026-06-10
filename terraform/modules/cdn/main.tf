locals {
  prefix = "${var.project_name}-${var.environment}"
}

# ─── Web CloudFront Distribution ──────────────────────────────────────────────
resource "aws_cloudfront_distribution" "web" {
  comment             = "${local.prefix} web distribution"
  enabled             = true
  is_ipv6_enabled     = true
  http_version        = "http2and3"
  price_class         = "PriceClass_100"   # US, Canada, Europe — expand as needed
  default_root_object = "index.html"

  origin {
    domain_name = var.web_alb_dns
    origin_id   = "web-alb"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"    # ALB is HTTP; CloudFront terminates TLS
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    custom_header {
      name  = "X-Forwarded-For-CF"
      value = "cloudfront"
    }
  }

  default_cache_behavior {
    target_origin_id       = "web-alb"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values {
      query_string = true
      headers      = ["Host", "Authorization", "Accept", "Accept-Language"]
      cookies {
        forward = "all"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0   # No caching for dynamic content — override per path behaviour below
  }

  # Cache static assets aggressively
  ordered_cache_behavior {
    path_pattern           = "/static/*"
    target_origin_id       = "web-alb"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 86400
    default_ttl = 86400
    max_ttl     = 31536000
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    # Swap for ACM cert when you add a custom domain:
    # acm_certificate_arn      = var.acm_certificate_arn
    # ssl_support_method        = "sni-only"
    # minimum_protocol_version  = "TLSv1.2_2021"
  }

  logging_config {
    bucket          = aws_s3_bucket.cf_logs.bucket_domain_name
    prefix          = "web-cf/"
    include_cookies = false
  }

  tags = { Name = "${local.prefix}-web-cf" }
}

# ─── API CloudFront Distribution ──────────────────────────────────────────────
resource "aws_cloudfront_distribution" "api" {
  comment         = "${local.prefix} api distribution"
  enabled         = true
  is_ipv6_enabled = true
  http_version    = "http2and3"
  price_class     = "PriceClass_100"

  origin {
    domain_name = var.api_alb_dns
    origin_id   = "api-alb"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "api-alb"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values {
      query_string = true
      headers      = ["*"]   # Forward all headers for API
      cookies {
        forward = "all"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  logging_config {
    bucket          = aws_s3_bucket.cf_logs.bucket_domain_name
    prefix          = "api-cf/"
    include_cookies = false
  }

  tags = { Name = "${local.prefix}-api-cf" }
}

# ─── CloudFront Logs Bucket ───────────────────────────────────────────────────
data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "cf_logs" {
  bucket        = "${local.prefix}-cf-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = false
}

resource "aws_s3_bucket_ownership_controls" "cf_logs" {
  bucket = aws_s3_bucket.cf_logs.id
  rule   { object_ownership = "BucketOwnerPreferred" }
}

resource "aws_s3_bucket_acl" "cf_logs" {
  depends_on = [aws_s3_bucket_ownership_controls.cf_logs]
  bucket     = aws_s3_bucket.cf_logs.id
  acl        = "log-delivery-write"
}

resource "aws_s3_bucket_lifecycle_configuration" "cf_logs" {
  bucket = aws_s3_bucket.cf_logs.id
  rule {
    id     = "expire-logs"
    status = "Enabled"
    filter { prefix = "" }
    expiration { days = 90 }
  }
}
