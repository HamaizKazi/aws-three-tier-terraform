# --------------------------------------------------
# RDS DB SUBNET GROUP
# --------------------------------------------------

resource "aws_db_subnet_group" "main" {
  name        = "${var.project_name}-db-subnet-group"
  description = "Private subnets for the RDS database"

  subnet_ids = [
    aws_subnet.db_private_a.id,
    aws_subnet.db_private_b.id
  ]

  tags = {
    Name    = "${var.project_name}-db-subnet-group"
    Project = var.project_name
  }
}

resource "aws_db_parameter_group" "mysql" {
  name_prefix = "${var.project_name}-mysql-"
  family      = "mysql8.4"
  description = "Enable MySQL general and slow query logging"

  parameter {
    name  = "general_log"
    value = "1"
  }

  parameter {
    name  = "slow_query_log"
    value = "1"
  }

  parameter {
    name  = "log_output"
    value = "FILE"
  }

  parameter {
    name  = "long_query_time"
    value = "2"
  }

  tags = {
    Name    = "${var.project_name}-mysql-parameters"
    Project = var.project_name
  }
}


# --------------------------------------------------
# RDS MYSQL DATABASE
# --------------------------------------------------

resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-mysql"

  engine               = "mysql"
  engine_version       = "8.4.11"
  instance_class       = var.db_instance_class
  parameter_group_name = aws_db_parameter_group.mysql.name

  db_name  = var.db_instance_name
  username = var.db_master_username
  password = var.db_password

  allocated_storage = 20
  storage_type      = "gp3"
  port              = 3306

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]

  publicly_accessible = false
  storage_encrypted   = true

  multi_az                   = false
  backup_retention_period    = 1
  auto_minor_version_upgrade = true

  deletion_protection = true
  skip_final_snapshot = true

  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  enabled_cloudwatch_logs_exports = [
    "error",
    "general",
    "slowquery"
  ]

  depends_on = [
    aws_cloudwatch_log_group.rds
    aws_iam_role_policy_attachment.rds_monitoring
  ]

  tags = {
    Name    = "${var.project_name}-mysql"
    Project = var.project_name
  }
}