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
  description = "Amazon Linux 2 AMI ID"
  type        = string
  default     = "ami-04dd8f0d80ed6323e"
}

variable "ssh_allowed_ip" {
  description = "IP address allowed for SSH access (CIDR format)"
  type        = string
  default     = "103.175.48.92/32"
}
