resource "aws_s3_bucket" "asset_bucket" {
    bucket = "${var.project_name}-${var.environment}-asset"

    tags = {
        env = var.environment
    }

    cors_rule {
      allowed_headers = ["*"]
      allowed_methods = ["HEAD", "GET", "PUT", "POST", "DELETE"]
      allowed_origins = ["*"]
      expose_headers  = ["Access-Control-Allow-Origin"]
      max_age_seconds = 3000
    }
}

resource "aws_s3_bucket_policy" "asset_bucket_policy" {
    bucket = aws_s3_bucket.asset_bucket.id

    policy = jsonencode({
        Version = "2008-10-17"
        Id      = "PolicyForCloudFrontPrivateContent"
        Statement = [
            {
                Sid       = "AllowCloudFrontServicePrincipal"
                Effect    = "Allow"
                Principal = {
                    Service = "cloudfront.amazonaws.com"
                }
                Action   = "s3:GetObject"
                Resource = "arn:aws:s3:::${var.project_name}-${var.environment}-asset/*"
                Condition = {
                    StringEquals = {
                        "AWS:SourceArn" = aws_cloudfront_distribution.cloudfront_distribution.arn
                    }
                }
            }
        ]
    })
}

resource "aws_cloudfront_origin_access_control" "origin_access_control" {
    name        = "${var.project_name}-${var.environment}"
    description = "Default Origin Access Control"
    origin_access_control_origin_type = "s3"
    signing_behavior                  = "always"
    signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "cloudfront_distribution" {
  origin {
    domain_name = "${var.project_name}-${var.environment}-asset.s3.${var.region}.amazonaws.com"
    origin_id   = aws_s3_bucket.asset_bucket.id
    connection_attempts = 3
    connection_timeout = 10
    origin_access_control_id = aws_cloudfront_origin_access_control.origin_access_control.id
  }

  enabled             = true
  http_version        = "http2"

  default_cache_behavior {
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"] 
    target_origin_id = aws_s3_bucket.asset_bucket.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.origin_request_policy.id
    viewer_protocol_policy = "redirect-to-https"
    cache_policy_id        = aws_cloudfront_cache_policy.default_cache_policy.id
    compress               = true
    response_headers_policy_id = "60669652-455b-4ae9-85a4-c4c02393f86c"
  }

  comment = "${var.project_name}-${var.environment}-Distribution"

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

resource "aws_cloudfront_cache_policy" "default_cache_policy" {
  name = "${var.project_name}-${var.environment}-CachePolicy"

  default_ttl = 86400
  max_ttl     = 31536000
  min_ttl     = 1

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "all"
    }
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true
    headers_config {
      header_behavior = "whitelist"
      headers {
        items = [ "Access-Control-Request-Headers", "Access-Control-Request-Method", "Origin" ]
      }
    }
    query_strings_config {
      query_string_behavior = "all"
    }
  }
}

resource "aws_cloudfront_origin_request_policy" "origin_request_policy" {
  name    = "${var.project_name}-${var.environment}-Custom-Managed-CachingDisabled"
  comment = "Managed-CachingDisabled Origin Request Policy"

  cookies_config {
    cookie_behavior = "none"
  }
  headers_config {
    header_behavior = "whitelist"
      headers {
        items = [ "Access-Control-Request-Headers", "Access-Control-Request-Method", "Origin" ]
      }
  }
  query_strings_config {
    query_string_behavior = "none"
  }
}

resource "aws_cloudfront_cache_policy" "my_cache_policy" {
  name    = "${var.project_name}-${var.environment}-Custom-Managed-CachingDisabled"
  comment = "Managed-CachingDisabled Cache Policy"

  default_ttl = 0
  max_ttl     = 0
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
    enable_accept_encoding_gzip = false
  }
}

resource "aws_cloudfront_distribution" "api_cloudfront_distribution" {
  origin {
    domain_name = var.alb_domain
    origin_id   = var.alb_id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols = ["TLSv1.2"]
    }
  }

  enabled             = true
  http_version        = "http2"

  default_cache_behavior {
    allowed_methods = ["GET", "HEAD", "DELETE", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods = ["GET", "HEAD"]
    target_origin_id = var.alb_id

    viewer_protocol_policy = "redirect-to-https"
    cache_policy_id        = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3"
    response_headers_policy_id = "60669652-455b-4ae9-85a4-c4c02393f86c"
    compress               = true
  }

  comment = "${var.project_name}-${var.environment}-API"

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  lifecycle {
    ignore_changes = [
      aliases,
      viewer_certificate[0].acm_certificate_arn,
      viewer_certificate[0].cloudfront_default_certificate,
      viewer_certificate[0].minimum_protocol_version,
      viewer_certificate[0].ssl_support_method,
    ]
  }  

}

resource "aws_cloudfront_distribution" "cms_cloudfront_distribution" {
  origin {
    domain_name = var.alb_domain
    origin_id   = var.alb_id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols = ["TLSv1.2"]
    }
  }

  enabled             = true
  http_version        = "http2"

  default_cache_behavior {
    allowed_methods = ["GET", "HEAD", "DELETE", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods = ["GET", "HEAD"]
    target_origin_id = var.alb_id

    viewer_protocol_policy = "redirect-to-https"
    cache_policy_id        = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3"
    response_headers_policy_id = "60669652-455b-4ae9-85a4-c4c02393f86c"
    compress               = true
  }

  comment = "${var.project_name}-${var.environment}-CMS"

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  
  lifecycle {
    ignore_changes = [
      aliases,
      viewer_certificate[0].acm_certificate_arn,
      viewer_certificate[0].cloudfront_default_certificate,
      viewer_certificate[0].minimum_protocol_version,
      viewer_certificate[0].ssl_support_method,
    ]
  } 

}

resource "aws_cloudfront_distribution" "web_cloudfront_distribution" {
  origin {
    domain_name = var.alb_domain
    origin_id   = var.alb_id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols = ["TLSv1.2"]
    }
  }

  enabled             = true
  http_version        = "http2"

  default_cache_behavior {
    allowed_methods = ["GET", "HEAD", "DELETE", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods = ["GET", "HEAD"]
    target_origin_id = var.alb_id

    viewer_protocol_policy = "redirect-to-https"
    cache_policy_id        = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3"
    response_headers_policy_id = "60669652-455b-4ae9-85a4-c4c02393f86c"
    compress               = true
  }

  comment = "${var.project_name}-${var.environment}-WEB"

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  lifecycle {
    ignore_changes = [
      aliases,
      viewer_certificate[0].acm_certificate_arn,
      viewer_certificate[0].cloudfront_default_certificate,
      viewer_certificate[0].minimum_protocol_version,
      viewer_certificate[0].ssl_support_method,
    ]
  } 

}