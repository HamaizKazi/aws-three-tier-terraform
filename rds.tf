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


# --------------------------------------------------
# RDS MYSQL DATABASE
# --------------------------------------------------

resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-mysql"

  engine         = "mysql"
  instance_class = var.db_instance_class

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

  deletion_protection = false
  skip_final_snapshot = true

  tags = {
    Name    = "${var.project_name}-mysql"
    Project = var.project_name
  }
}