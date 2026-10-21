# ==================================================
# WEB TIER AUTO SCALING GROUP
# ==================================================

resource "aws_autoscaling_group" "web" {
  name = "${var.project_name}-web-asg"

  desired_capacity = var.web_desired_capacity
  min_size         = var.web_min_size
  max_size         = var.web_max_size

  vpc_zone_identifier = [
    aws_subnet.web_private_a.id,
    aws_subnet.web_private_b.id
  ]

  health_check_type         = "ELB"
  health_check_grace_period = 300

  # Register instances with the public ALB's web target group.
  target_group_arns = [
    aws_lb_target_group.web.arn
  ]

  launch_template {
    id      = aws_launch_template.web.id
    version = aws_launch_template.web.latest_version
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-web-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }

  tag {
    key                 = "Tier"
    value               = "web"
    propagate_at_launch = true
  }
}


# ==================================================
# APP TIER AUTO SCALING GROUP
# ==================================================

resource "aws_autoscaling_group" "app" {
  name = "${var.project_name}-app-asg"

  desired_capacity = var.app_desired_capacity
  min_size         = var.app_min_size
  max_size         = var.app_max_size

  vpc_zone_identifier = [
    aws_subnet.app_private_a.id,
    aws_subnet.app_private_b.id
  ]

  health_check_type         = "ELB"
  health_check_grace_period = 300

  # Register instances with the internal ALB's app target group.
  target_group_arns = [
    aws_lb_target_group.app.arn
  ]

  launch_template {
    id      = aws_launch_template.app.id
    version = aws_launch_template.app.latest_version
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-app-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }

  tag {
    key                 = "Tier"
    value               = "app"
    propagate_at_launch = true
  }
}