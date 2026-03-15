variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-southeast-3"
}

variable "key_name" {
  description = "EC2 KeyPair name for SSH access"
  type        = string
  default     = "Keypair-demoweek1"
}

variable "ami_id" {
  description = "Amazon Linux 2023 AMI ID"
  type        = string
  default     = "ami-0d5f3e23c61fbb3e8"
}

variable "ssh_allowed_ip" {
  description = "IP address allowed for SSH access (CIDR format)"
  type        = string
}
