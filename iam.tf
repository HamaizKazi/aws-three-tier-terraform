# ==================================================
# 1. SHARED EC2 SESSION MANAGER ROLE
# ==================================================

resource "aws_iam_role" "ec2_ssm" {
  name = "${var.project_name}-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "ec2.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name    = "${var.project_name}-ec2-ssm-role"
    Project = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_ssm" {
  name = "${var.project_name}-ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm.name
}


# ==================================================
# 2. APP-TIER ROLE
# ==================================================

resource "aws_iam_role" "app_tier" {
  name = "${var.project_name}-app-tier-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "ec2.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name    = "${var.project_name}-app-tier-role"
    Project = var.project_name
  }
}

# App-tier instances also need Session Manager.
resource "aws_iam_role_policy_attachment" "app_tier_ssm" {
  role       = aws_iam_role.app_tier.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Allow the app tier to read only its required parameters.
resource "aws_iam_role_policy" "app_tier_parameters" {
  name = "${var.project_name}-app-tier-parameters"
  role = aws_iam_role.app_tier.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Action = [
        "ssm:GetParameter",
        "ssm:GetParameters"
      ]

      Resource = [
        aws_ssm_parameter.master_username.arn,
        aws_ssm_parameter.db_password.arn,
        aws_ssm_parameter.endpoint.arn,
        aws_ssm_parameter.db_instance_name.arn
      ]
    }]
  })
}

resource "aws_iam_instance_profile" "app_tier" {
  name = "${var.project_name}-app-tier-profile"
  role = aws_iam_role.app_tier.name
}