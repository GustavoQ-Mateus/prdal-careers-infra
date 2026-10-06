variable "nome" { type = string }
variable "bucket_web" { type = string }
variable "dominio_alb" { type = string }
variable "dominio_web" {
  type    = string
  default = null
}
variable "certificado_web_arn" {
  type    = string
  default = null
}
variable "alb_origin_protocol_policy" {
  type    = string
  default = "https-only"
}
variable "alb_origin_header_value" {
  type      = string
  default   = null
  sensitive = true
}
variable "alb_origin_header_habilitado" {
  type    = bool
  default = false
}

data "aws_cloudfront_cache_policy" "managed_cachingdisabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_cache_policy" "managed_cachingoptimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_origin_request_policy" "managed_allviewer_except_hostheader" {
  name = "Managed-AllViewerExceptHostHeader"
}

resource "aws_s3_bucket" "web" {
  bucket        = var.bucket_web
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "web" {
  bucket                  = aws_s3_bucket.web.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "web" {
  bucket = aws_s3_bucket.web.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_cloudfront_origin_access_control" "web" {
  name                              = var.nome
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_response_headers_policy" "seguranca" {
  name = "${var.nome}-seguranca"
  security_headers_config {
    content_security_policy {
      content_security_policy = "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; object-src 'none'; base-uri 'self'; frame-ancestors 'none'"
      override                = true
    }
    content_type_options { override = true }
    frame_options {
      frame_option = "DENY"
      override     = true
    }
    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      override                   = true
    }
  }
}

resource "aws_cloudfront_function" "web_rotas" {
  name    = "${var.nome}-web-rotas"
  runtime = "cloudfront-js-2.0"
  publish = true
  code    = "function handler(event) { var request = event.request; if (!request.uri.startsWith('/api/') && !request.uri.includes('.')) { request.uri = '/index.html'; } return request; }"
}

resource "aws_cloudfront_distribution" "principal" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"
  aliases             = var.dominio_web == null ? [] : [var.dominio_web]

  origin {
    domain_name              = aws_s3_bucket.web.bucket_regional_domain_name
    origin_id                = "web"
    origin_access_control_id = aws_cloudfront_origin_access_control.web.id
  }

  origin {
    domain_name = var.dominio_alb
    origin_id   = "api"
    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_protocol_policy   = var.alb_origin_protocol_policy
      origin_ssl_protocols     = ["TLSv1.2"]
      origin_read_timeout      = 60
      origin_keepalive_timeout = 60
    }
    dynamic "custom_header" {
      for_each = var.alb_origin_header_habilitado ? [1] : []
      content {
        name  = "X-Prdal-Origin-Token"
        value = var.alb_origin_header_value
      }
    }
  }

  default_cache_behavior {
    target_origin_id           = "web"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    cache_policy_id            = data.aws_cloudfront_cache_policy.managed_cachingoptimized.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.seguranca.id
    compress                   = true
    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.web_rotas.arn
    }
  }

  ordered_cache_behavior {
    path_pattern               = "/api/*"
    target_origin_id           = "api"
    viewer_protocol_policy     = "https-only"
    allowed_methods            = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods             = ["GET", "HEAD"]
    cache_policy_id            = data.aws_cloudfront_cache_policy.managed_cachingdisabled.id
    origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.managed_allviewer_except_hostheader.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.seguranca.id
    compress                   = false
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.dominio_web == null
    acm_certificate_arn            = var.certificado_web_arn
    ssl_support_method             = var.dominio_web == null ? null : "sni-only"
    minimum_protocol_version       = "TLSv1.2_2021"
  }
}

resource "aws_s3_bucket_policy" "web" {
  bucket = aws_s3_bucket.web.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.web.arn}/*"
      Condition = {
        StringEquals = { "AWS:SourceArn" = aws_cloudfront_distribution.principal.arn }
      }
    }]
  })
}

output "dominio" { value = aws_cloudfront_distribution.principal.domain_name }
output "bucket" { value = aws_s3_bucket.web.bucket }
