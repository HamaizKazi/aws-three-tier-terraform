resource "aws_cloudwatch_log_group" "rds" {
  for_each = toset(["error", "general", "slowquery"])

  name              = "/aws/rds/instance/${var.project_name}-mysql/${each.key}"
  retention_in_days = 30

  tags = {
    Project = var.project_name
    Service = "rds"
  }
}