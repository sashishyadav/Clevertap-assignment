# ---------------------------------------------------------------------------
# S3 (private static assets) + CloudFront (CDN).
# CloudFront has two origins:
#   - ALB          -> dynamic app traffic (default behavior)
#   - S3 bucket    -> /static/* served from the edge, private via OAC
# Offloading static assets to the edge cuts ALB/ECS load and egress cost.
# ---------------------------------------------------------------------------

# --- S3 bucket --------------------------------------------------------------
resource "aws_s3_bucket" "assets" {
  bucket = "${local.name}-assets-${data.aws_caller_identity.current.account_id}"
  tags   = { Name = "${local.name}-assets" }
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket_public_access_block" "assets" {
  bucket                  = aws_s3_bucket.assets.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Lifecycle: drop non-current versions after 90 days to control storage cost.
resource "aws_s3_bucket_lifecycle_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id
  rule {
    id     = "expire-noncurrent"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# --- CloudFront -------------------------------------------------------------
# Origin Access Control lets CloudFront read the private bucket (no public S3).
resource "aws_cloudfront_origin_access_control" "s3" {
  name                              = "${local.name}-s3-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# AWS-managed policies (data sources so we don't hard-code IDs).
data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "all_viewer" {
  name = "Managed-AllViewer"
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  comment             = "${local.name} CDN"
  default_root_object = ""
  price_class         = "PriceClass_100" # NA + EU edges only — cost saving

  # Dynamic origin: the ALB.
  origin {
    domain_name = aws_lb.this.dns_name
    origin_id   = "alb"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = var.acm_certificate_arn == "" ? "http-only" : "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Static origin: the private S3 bucket via OAC.
  origin {
    domain_name              = aws_s3_bucket.assets.bucket_regional_domain_name
    origin_id                = "s3-assets"
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
  }

  # Default behavior -> ALB (dynamic, uncached).
  default_cache_behavior {
    target_origin_id       = "alb"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]

    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer.id
  }

  # /static/* -> S3, aggressively cached at the edge.
  ordered_cache_behavior {
    path_pattern           = "/static/*"
    target_origin_id       = "s3-assets"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    cache_policy_id = data.aws_cloudfront_cache_policy.caching_optimized.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Demo uses the default *.cloudfront.net cert. For a custom domain, supply an
  # ACM cert in us-east-1 and set aliases + viewer_certificate accordingly.
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  # NOTE: to attach WAF to CloudFront, create a scope="CLOUDFRONT" Web ACL in
  # us-east-1 (separate provider alias) and set web_acl_id here. The regional
  # WAF in waf.tf already protects the ALB origin.

  tags = { Name = "${local.name}-cdn" }
}

# --- Bucket policy: allow only this CloudFront distribution to read ----------
resource "aws_s3_bucket_policy" "assets" {
  bucket = aws_s3_bucket.assets.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowCloudFrontOACRead"
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = ["s3:GetObject"]
      Resource  = "${aws_s3_bucket.assets.arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.this.arn
        }
      }
    }]
  })
}
