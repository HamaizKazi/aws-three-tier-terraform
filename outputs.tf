# ==================================================
# LOAD BALANCER OUTPUTS
# ==================================================

output "external_alb_dns_name" {
  description = "Public DNS name of the external Application Load Balancer"
  value       = aws_lb.external.dns_name
}

output "internal_alb_dns_name" {
  description = "Private DNS name of the internal Application Load Balancer"
  value       = aws_lb.internal.dns_name
}


# ==================================================
# DATABASE OUTPUTS
# ==================================================

output "rds_endpoint" {
  description = "RDS MySQL endpoint address"
  value       = aws_db_instance.main.address
}

output "rds_database_name" {
  description = "Initial database name"
  value       = aws_db_instance.main.db_name
}


# ==================================================
# NETWORK OUTPUTS
# ==================================================

output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.main.id
}


output "public_subnet_ids" {
  description = "Public subnet IDs"
  value = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]
}


output "private_app_subnet_ids" {
  description = "Application tier private subnet IDs"
  value = [
    aws_subnet.app_private_a.id,
    aws_subnet.app_private_b.id
  ]
}


output "private_db_subnet_ids" {
  description = "Database tier private subnet IDs"
  value = [
    aws_subnet.db_private_a.id,
    aws_subnet.db_private_b.id
  ]
}


# ==================================================
# COMPUTE OUTPUTS
# ==================================================

output "web_asg_name" {
  description = "Web tier Auto Scaling Group name"
  value       = aws_autoscaling_group.web.name
}


output "app_asg_name" {
  description = "Application tier Auto Scaling Group name"
  value       = aws_autoscaling_group.app.name
}