
# Monitor unhealthy targets for both ALB target groups.
# Alarms appear in CloudWatch but do not send notifications.

locals {
  monitored_target_groups = {
    web = {
      load_balancer = aws_lb.external.arn_suffix
      target_group  = aws_lb_target_group.web.arn_suffix
    }
    app = {
      load_balancer = aws_lb.internal.arn_suffix
      target_group  = aws_lb_target_group.app.arn_suffix
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_targets" {
  for_each = local.monitored_target_groups

  alarm_name          = "${var.project_name}-${each.key}-unhealthy-targets"
  alarm_description   = "Detect unhealthy ${each.key} ALB targets"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  threshold           = 1

  namespace   = "AWS/ApplicationELB"
  metric_name = "UnHealthyHostCount"
  period      = 60
  statistic   = "Maximum"

  treat_missing_data = "notBreaching"
  actions_enabled    = true

  dimensions = {
    LoadBalancer = each.value.load_balancer
    TargetGroup  = each.value.target_group
  }

  tags = {
    Project = var.project_name
    Tier    = each.key
  }
}
