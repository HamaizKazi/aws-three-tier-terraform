variable "project_name" {
  type    = string
  default = "aws-learning"
}

variable "region" {
  type    = string
  default = "ap-southeast-2"
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "public_a_cidr" {
  type    = string
  default = "10.20.0.0/24"
}

variable "public_b_cidr" {
  type    = string
  default = "10.20.1.0/24"
}

variable "web_private_a_cidr" {
  type    = string
  default = "10.20.2.0/24"
}

variable "web_private_b_cidr" {
  type    = string
  default = "10.20.3.0/24"
}

variable "app_private_a_cidr" {
  type    = string
  default = "10.20.4.0/24"
}

variable "app_private_b_cidr" {
  type    = string
  default = "10.20.5.0/24"
}

variable "db_private_a_cidr" {
  type    = string
  default = "10.20.6.0/24"
}

variable "db_private_b_cidr" {
  type    = string
  default = "10.20.7.0/24"
}

variable "db_master_username" {
  type    = string
  default = "dbadmin"
}

variable "db_instance_name" {
  type    = string
  default = "tododb"
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "db_instance_class" {
  description = "Instance class for the RDS database"
  type        = string
  default     = "db.t3.micro"
}


# ==================================================
# EC2 INSTANCE TYPES
# ==================================================

variable "web_instance_type" {
  description = "EC2 instance type for the web tier"
  type        = string
  default     = "t3.micro"
}

variable "app_instance_type" {
  description = "EC2 instance type for the app tier"
  type        = string
  default     = "t3.micro"
}


# ==================================================
# WEB TIER AUTO SCALING CAPACITY
# ==================================================

variable "web_desired_capacity" {
  description = "Desired number of web instances"
  type        = number
  default     = 2
}

variable "web_min_size" {
  description = "Minimum number of web instances"
  type        = number
  default     = 2
}

variable "web_max_size" {
  description = "Maximum number of web instances"
  type        = number
  default     = 4
}


# ==================================================
# APP TIER AUTO SCALING CAPACITY
# ==================================================

variable "app_desired_capacity" {
  description = "Desired number of app instances"
  type        = number
  default     = 2
}

variable "app_min_size" {
  description = "Minimum number of app instances"
  type        = number
  default     = 2
}

variable "app_max_size" {
  description = "Maximum number of app instances"
  type        = number
  default     = 4
}