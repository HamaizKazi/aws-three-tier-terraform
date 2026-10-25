data "aws_caller_identity" "kms" {}

data "aws_partition" "kms" {}



resource "aws_kms_key" "ssm" {
  description             = "Encrypt application SSM SecureString parameters"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableAccountIAMPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:${data.aws_partition.kms.partition}:iam::${data.aws_caller_identity.kms.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })

  tags = {
    Name    = "${var.project_name}-ssm-key"
    Project = var.project_name
  }
}

resource "aws_kms_alias" "ssm" {
  name          = "alias/${var.project_name}-ssm"
  target_key_id = aws_kms_key.ssm.key_id
}