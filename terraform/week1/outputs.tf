output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_ec2_id" {
  description = "Public EC2 Instance ID"
  value       = aws_instance.public.id
}

output "public_ec2_ip" {
  description = "Public EC2 Public IP"
  value       = aws_instance.public.public_ip
}

output "nat_gateway_ip" {
  description = "NAT Gateway Elastic IP"
  value       = aws_eip.nat.public_ip
}
