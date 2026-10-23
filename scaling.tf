# ==================================================
# WEB TIER CPU TARGET TRACKING POLICY
# ==================================================

resource "aws_autoscaling_policy" "web_cpu_tracking" {
  name = "${var.project_name}-web-cpu-target-tracking"

  autoscaling_group_name = aws_autoscaling_group.web.name

  policy_type = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    # Desired average CPU utilization
    target_value = 60.0

    # Prevent aggressive scaling
    disable_scale_in = false
  }
}


# ==================================================
# APP TIER CPU TARGET TRACKING POLICY
# ==================================================

resource "aws_autoscaling_policy" "app_cpu_tracking" {
  name = "${var.project_name}-app-cpu-target-tracking"

  autoscaling_group_name = aws_autoscaling_group.app.name

  policy_type = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    # Desired average CPU utilization
    target_value = 60.0

    # Allow scale-in when load decreases
    disable_scale_in = false
  }
}