resource "aws_ssm_parameter" "master_username" {
  name        = "master_username"
  description = "RDS database username"
  type        = "String"
  value       = var.db_master_username
  overwrite   = true

  tags = {
    Name    = "${var.project_name}-master-username"
    Project = var.project_name
  }
}

resource "aws_ssm_parameter" "db_password" {
  name        = "db_password"
  description = "RDS database password"
  type        = "SecureString"
  value       = var.db_password
  overwrite   = true

  tags = {
    Name    = "${var.project_name}-db-password"
    Project = var.project_name
  }
}

resource "aws_ssm_parameter" "endpoint" {
  name        = "endpoint"
  description = "RDS endpoint address"
  type        = "String"
  value       = aws_db_instance.main.address
  overwrite   = true

  tags = {
    Name    = "${var.project_name}-endpoint"
    Project = var.project_name
  }
}

resource "aws_ssm_parameter" "db_instance_name" {
  name        = "db_instance_name"
  description = "the initial database name configured in RDS"
  type        = "String"
  value       = var.db_instance_name
  overwrite   = true

  tags = {
    Name    = "${var.project_name}-db-instance-name"
    Project = var.project_name
  }
}