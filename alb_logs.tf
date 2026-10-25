data "aws_caller_identity" "alb_logs" {}

resource "aws_s3_bucket" "alb_logs" {
  bucket_prefix = "${var.project_name}-alb-logs-"

  tags = {
    Name    = "${var.project_name}-alb-logs"
    Project = var.project_name
  }
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowALBLogDelivery"
        Effect = "Allow"
        Principal = {
          Service = "logdelivery.elasticloadbalancing.amazonaws.com"
        }
        Action = "s3:PutObject"
        Resource = [
          "${aws_s3_bucket.alb_logs.arn}/external/AWSLogs/${data.aws_caller_identity.alb_logs.account_id}/*",
          "${aws_s3_bucket.alb_logs.arn}/internal/AWSLogs/${data.aws_caller_identity.alb_logs.account_id}/*"
        ]
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.alb_logs.arn,
          "${aws_s3_bucket.alb_logs.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}