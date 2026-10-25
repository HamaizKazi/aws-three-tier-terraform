# ==================================================
# PUBLIC LOAD BALANCER FOR THE WEB TIER
# ==================================================

resource "aws_lb" "external" {
  name               = "${var.project_name}-external-alb"
  internal           = false
  load_balancer_type = "application"

  drop_invalid_header_fields = true
  enable_deletion_protection = true

  security_groups = [aws_security_group.external_alb.id]
  subnets = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.id
    prefix  = "external"
    enabled = true
  }

  depends_on = [
    aws_s3_bucket_policy.alb_logs,
    aws_s3_bucket_public_access_block.alb_logs,
    aws_s3_bucket_server_side_encryption_configuration.alb_logs
  ]

  tags = {
    Name    = "${var.project_name}-external-alb"
    Project = var.project_name
    Tier    = "edge"
  }
}

resource "aws_lb_target_group" "web" {
  name        = "${var.project_name}-web-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name    = "${var.project_name}-web-tg"
    Project = var.project_name
    Tier    = "web"
  }
}

resource "aws_lb_listener" "external_http" {
  load_balancer_arn = aws_lb.external.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# ==================================================
# INTERNAL LOAD BALANCER FOR THE APP TIER
# ==================================================

resource "aws_lb" "internal" {
  name               = "${var.project_name}-internal-alb"
  internal           = true
  load_balancer_type = "application"

  drop_invalid_header_fields = true
  enable_deletion_protection = true

  security_groups = [aws_security_group.internal_alb.id]
  subnets = [
    aws_subnet.app_private_a.id,
    aws_subnet.app_private_b.id
  ]

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.id
    prefix  = "internal"
    enabled = true
  }

  depends_on = [
    aws_s3_bucket_policy.alb_logs,
    aws_s3_bucket_public_access_block.alb_logs,
    aws_s3_bucket_server_side_encryption_configuration.alb_logs
  ]

  tags = {
    Name    = "${var.project_name}-internal-alb"
    Project = var.project_name
    Tier    = "internal"
  }
}

resource "aws_lb_target_group" "app" {
  name        = "${var.project_name}-app-tg"
  port        = 4000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name    = "${var.project_name}-app-tg"
    Project = var.project_name
    Tier    = "app"
  }
}

resource "aws_lb_listener" "internal_http" {
  load_balancer_arn = aws_lb.internal.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}