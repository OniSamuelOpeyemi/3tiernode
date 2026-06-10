variable "aws_region" {
  description = "Primary AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project identifier used in resource naming"
  type        = string
  default     = "node3tier"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# variable "availability_zones" {
#  description = "List of AZs to deploy into"
#  type        = list(string)
#  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
# }

#  Database
variable "db_name" {
  description = "Database name"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  sensitive   = true

  validation {
    condition     = var.db_username != "admin" && var.db_username != "postgres" && var.db_username != "root"
    error_message = "db_username cannot be a reserved username such as admin, postgres, or root. Choose a different user."
  }
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}

# ECS task sizing
variable "web_cpu"    { type = number; default = 512 }
variable "web_memory" { type = number; default = 1024 }
variable "api_cpu"    { type = number; default = 512 }
variable "api_memory" { type = number; default = 1024 }

variable "web_desired_count" { type = number; default = 2 }
variable "api_desired_count" { type = number; default = 2 }

# Notifications
variable "alarm_email" {
  description = "Email for CloudWatch alarm notifications"
  type        = string
  default     = ""
}
