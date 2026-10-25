resource "aws_security_group" "external_alb" {
  name        = "${var.project_name}-external-alb-sg"
  description = "Allow HTTP from the internet to the public ALB"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name    = "${var.project_name}-external-alb-sg"
    Project = var.project_name
    Tier    = "edge"
  }
}

resource "aws_security_group" "web_tier" {
  name        = "${var.project_name}-web-tier-sg"
  description = "Allow HTTP from the external ALB to the web tier"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from external ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.external_alb.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-web-tier-sg"
    Project = var.project_name
    Tier    = "web"
  }
}

resource "aws_security_group" "internal_alb" {
  name        = "${var.project_name}-internal-alb-sg"
  description = "Allow HTTP from the web tier to the internal ALB"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name    = "${var.project_name}-internal-alb-sg"
    Project = var.project_name
    Tier    = "internal"
  }
}

resource "aws_security_group" "app_tier" {
  name        = "${var.project_name}-app-tier-sg"
  description = "Allow app traffic from the internal ALB to the application tier"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "App port from internal ALB"
    from_port       = 4000
    to_port         = 4000
    protocol        = "tcp"
    security_groups = [aws_security_group.internal_alb.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-app-tier-sg"
    Project = var.project_name
    Tier    = "app"
  }
}

resource "aws_security_group" "db" {
  name        = "${var.project_name}-db-sg"
  description = "Allow MySQL only from the application tier"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from app tier"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app_tier.id]
  }

  egress = []

  tags = {
    Name    = "${var.project_name}-db-sg"
    Project = var.project_name
    Tier    = "db"
  }
}

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  ingress = []
  egress  = []

  tags = {
    Name    = "${var.project_name}-default-restricted"
    Project = var.project_name
  }
}

resource "aws_vpc_security_group_ingress_rule" "external_alb_http" {
  security_group_id = aws_security_group.external_alb.id
  description       = "Public HTTP access to external ALB"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80
}

resource "aws_vpc_security_group_egress_rule" "external_alb_to_web" {
  security_group_id            = aws_security_group.external_alb.id
  referenced_security_group_id = aws_security_group.web_tier.id
  description                  = "HTTP requests and health checks to web tier"

  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80
}

resource "aws_vpc_security_group_ingress_rule" "internal_alb_from_web" {
  security_group_id            = aws_security_group.internal_alb.id
  referenced_security_group_id = aws_security_group.web_tier.id
  description                  = "HTTP from web tier to internal ALB"

  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80
}

resource "aws_vpc_security_group_egress_rule" "internal_alb_to_app" {
  security_group_id            = aws_security_group.internal_alb.id
  referenced_security_group_id = aws_security_group.app_tier.id
  description                  = "Application requests and health checks to app tier"

  ip_protocol = "tcp"
  from_port   = 4000
  to_port     = 4000
}