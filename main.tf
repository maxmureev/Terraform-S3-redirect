##########################################################
# Announce my.cdn.domain CDN Certificate
data "aws_acm_certificate" "my_certificate" {
  domain   = "${var.main["cdn_domain"]}"
  statuses = ["ISSUED"]
}

##########################################################
# Create Bucket For my.cdn.domain
resource "aws_s3_bucket" "my_bucket" {
  bucket = "${var.main["bucket_name"]}"
  acl    = "private"
  region = "${var.region}"

  tags {
    Name = "${var.main["bucket_name"]}"
  }

  policy = <<EOF
{
  "Id": "Policy1516899566603",
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Stmt1516899563175",
      "Action": "s3:GetObject",
      "Effect": "Allow",
      "Resource": "arn:aws:s3:::${var.main["bucket_name"]}/*",
      "Principal": "*"
    }
  ]
}
EOF

  website {
    index_document = "index.html"
    error_document = "error.html"
  }
}

# Create index.html file And Redirect to my.rdr.domain
resource "aws_s3_bucket_object" "index_file" {
  bucket           = "${aws_s3_bucket.my_bucket.id}"
  acl              = "private"
  source           = "/dev/null"
  key              = "index.html"
  content_type     = "text/html"
  website_redirect = "${var.main["rdr_domain"]}"
}

# Create error.html file And Redirect to my.rdr.domain
resource "aws_s3_bucket_object" "error_file" {
  bucket           = "${aws_s3_bucket.my_bucket.id}"
  acl              = "private"
  source           = "/dev/null"
  key              = "error.html"
  content_type     = "text/html"
  website_redirect = "${var.main["rdr_domain"]}"
}

# Create file.name And Its Content
resource "aws_s3_bucket_object" "target_file" {
  bucket       = "${aws_s3_bucket.my_bucket.id}"
  acl          = "private"
  source       = "files/target.file"
  key          = "target.file"
  content_type = "text/html"
}

##########################################################
# Create CDN For my.rdr.domain
resource "aws_cloudfront_distribution" "my_cdn" {
  origin {
    domain_name = "${aws_s3_bucket.my_bucket.website_endpoint}"
    origin_id   = "CDN for ${var.main["bucket_name"]}"

    custom_origin_config {
      origin_protocol_policy = "http-only"
      http_port              = "80"
      https_port             = "443"
      origin_ssl_protocols   = ["TLSv1.1"]
    }
  }

  enabled         = true
  is_ipv6_enabled = true
  comment         = "CDN for ${var.main["cdn_domain"]}"

  aliases = ["${var.main["cdn_domain"]}"]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${var.main["bucket_name"]}"
    compress         = "True"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    viewer_protocol_policy = "redirect-to-https"
    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  price_class = "PriceClass_All"

  viewer_certificate {
    cloudfront_default_certificate = "false"
    acm_certificate_arn            = "${data.aws_acm_certificate.my_certificate.arn}"
    minimum_protocol_version       = "TLSv1.1_2016"
    ssl_support_method             = "sni-only"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

##########################################################
# Create my.cdn.domain Public Domain Zone
resource "aws_route53_zone" "my_dns_zone" {
  name = "${var.main["cdn_domain"]}"
}

resource "aws_route53_record" "my_domain" {
  zone_id = "${aws_route53_zone.my_dns_zone.zone_id}"
  name    = "${var.main["cdn_domain"]}"
  type    = "A"

  alias {
    name                   = "${aws_cloudfront_distribution.my_cdn.domain_name}"
    zone_id                = "${aws_cloudfront_distribution.my_cdn.hosted_zone_id}"
    evaluate_target_health = false
  }
}
