output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "nginx_public_ip" {
  description = "Nginx Server Public IP"
  value       = aws_instance.nginx.public_ip
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

output "public_url" {
  description = "Application Public URL"
  value       = "http://${aws_instance.nginx.public_ip}"
}
