variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-southeast-3"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t3.micro", "t3.small", "t3.medium", "t3.large"], var.instance_type)
    error_message = "Allowed values: t3.micro, t3.small, t3.medium, t3.large."
  }
}

variable "ami_id" {
  description = "Amazon Linux 2023 AMI ID"
  type        = string
  default     = "ami-0d5f3e23c61fbb3e8"
}

variable "db_username" {
  description = "RDS master username"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "RDS master password (minimum 8 characters)"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "RDS database name"
  type        = string
  default     = "bookcatalog"
}

variable "ecr_image" {
  description = "ECR image URI (e.g. 123456789.dkr.ecr.ap-southeast-3.amazonaws.com/bookcatalog:latest)"
  type        = string
}

variable "alert_email" {
  description = "Email address for CloudWatch alarms and Let's Encrypt notifications"
  type        = string
}
