output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "nginx_eip" {
  description = "Nginx Server Elastic IP"
  value       = aws_eip.nginx.public_ip
}

output "website_url" {
  description = "Application URL (HTTPS via nip.io)"
  value       = "https://${aws_eip.nginx.public_ip}.nip.io"
}

output "app_private_ip" {
  description = "App Server Private IP"
  value       = aws_instance.app.private_ip
}

output "rds_endpoint" {
  description = "RDS PostgreSQL Endpoint"
  value       = aws_db_instance.postgres.address
}

output "s3_bucket_name" {
  description = "S3 Bucket Name"
  value       = aws_s3_bucket.app.id
}

output "sns_topic_arn" {
  description = "SNS Topic ARN for alarms"
  value       = aws_sns_topic.alarms.arn
}

output "log_group_name" {
  description = "CloudWatch Log Group Name"
  value       = aws_cloudwatch_log_group.app.name
}
