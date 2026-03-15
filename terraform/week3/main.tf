terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# =========================================================
# 1. VPC & Networking
# =========================================================
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "Final-Monitoring-VPC"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Final-IGW"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "w3-public-subnet"
  }
}

resource "aws_subnet" "private_app" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "w3-private-subnet-app"
  }
}

resource "aws_subnet" "private_db1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "w3-private-subnet-db1"
  }
}

resource "aws_subnet" "private_db2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "w3-private-subnet-db2"
  }
}

resource "aws_eip" "nat" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "w3-nat-gw"
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "w3-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "w3-private-rt"
  }
}

resource "aws_route_table_association" "private_app" {
  subnet_id      = aws_subnet.private_app.id
  route_table_id = aws_route_table.private.id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.aws_region}.s3"

  route_table_ids = [aws_route_table.private.id]

  tags = {
    Name = "w3-s3-endpoint"
  }
}

# =========================================================
# 2. Security Groups
# =========================================================
resource "aws_security_group" "nginx" {
  name        = "w3-nginx-sg"
  description = "Allow HTTP/HTTPS and SSH"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "w3-nginx-sg"
  }
}

resource "aws_security_group" "app" {
  name        = "w3-app-sg"
  description = "Allow port 3000 from Nginx"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.nginx.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "w3-app-sg"
  }
}

resource "aws_security_group" "rds" {
  name        = "w3-rds-sg"
  description = "Allow Postgres from App"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "w3-rds-sg"
  }
}

# =========================================================
# 3. IAM Roles
# =========================================================
resource "aws_iam_role" "app" {
  name = "w3-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "app_ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "app_ecr" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "app_cloudwatch" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy" "app_s3" {
  name = "w3-s3-access"
  role = aws_iam_role.app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject", "s3:DeleteObject"]
      Resource = "${aws_s3_bucket.app.arn}/*"
    }]
  })
}

resource "aws_iam_instance_profile" "app" {
  name = "w3-app-instance-profile"
  role = aws_iam_role.app.name
}

resource "aws_iam_role" "nginx" {
  name = "w3-nginx-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "nginx_ssm" {
  role       = aws_iam_role.nginx.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "nginx" {
  name = "w3-nginx-instance-profile"
  role = aws_iam_role.nginx.name
}

# =========================================================
# 4. S3 Bucket
# =========================================================
resource "aws_s3_bucket" "app" {
  tags = {
    Name = "w3-app-bucket"
  }
}

resource "aws_s3_bucket_versioning" "app" {
  bucket = aws_s3_bucket.app.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "app" {
  bucket = aws_s3_bucket.app.id

  rule {
    id     = "CleanupOldVersionsAndMarkers"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    expiration {
      expired_object_delete_marker = true
    }
  }
}

resource "aws_s3_bucket_public_access_block" "app" {
  bucket = aws_s3_bucket.app.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "app" {
  bucket     = aws_s3_bucket.app.id
  depends_on = [aws_s3_bucket_public_access_block.app]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.app.arn}/*"
    }]
  })
}

# =========================================================
# 5. RDS PostgreSQL Multi-AZ
# =========================================================
resource "aws_db_subnet_group" "main" {
  name       = "w3-db-subnet-group"
  subnet_ids = [aws_subnet.private_db1.id, aws_subnet.private_db2.id]

  tags = {
    Name = "w3-db-subnet-group"
  }
}

resource "aws_db_instance" "postgres" {
  engine               = "postgres"
  engine_version       = "15"
  instance_class       = "db.t3.micro"
  allocated_storage    = 20
  username             = var.db_username
  password             = var.db_password
  db_name              = var.db_name
  publicly_accessible  = false
  db_subnet_group_name = aws_db_subnet_group.main.name
  multi_az             = true
  skip_final_snapshot  = true

  backup_retention_period = 7
  preferred_backup_window = "20:00-21:00"

  vpc_security_group_ids = [aws_security_group.rds.id]

  tags = {
    Name = "w3-rds-postgres"
  }
}

# =========================================================
# 6. App Server (Private EC2)
# =========================================================
resource "aws_instance" "app" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private_app.id
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile   = aws_iam_instance_profile.app.name

  user_data = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y docker aws-cli
    systemctl enable --now docker
    usermod -aG docker ec2-user

    aws ecr get-login-password --region ${var.aws_region} | \
      docker login --username AWS --password-stdin ${var.ecr_image}

    cat <<ENVFILE > /home/ec2-user/.env
    DB_HOST=${aws_db_instance.postgres.address}
    DB_USER=${var.db_username}
    DB_PASSWORD=${var.db_password}
    DB_NAME=${var.db_name}
    AWS_BUCKET_NAME=${aws_s3_bucket.app.id}
    AWS_REGION=${var.aws_region}
    ENVFILE

    docker pull ${var.ecr_image}
    sleep 10
    docker run -d --name app \
      --restart always \
      --network host \
      --env-file /home/ec2-user/.env \
      --log-driver=awslogs \
      --log-opt awslogs-group=${aws_cloudwatch_log_group.app.name} \
      --log-opt awslogs-stream=app-logs \
      --log-opt awslogs-region=${var.aws_region} \
      ${var.ecr_image}
  EOF

  tags = {
    Name = "w3-app-server"
  }
}

# =========================================================
# 7. Nginx Server (Public EC2) + EIP
# =========================================================
resource "aws_eip" "nginx" {
  domain = "vpc"
}

resource "aws_instance" "nginx" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.nginx.id]
  iam_instance_profile   = aws_iam_instance_profile.nginx.name

  depends_on = [aws_instance.app]

  user_data = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y nginx augeas-libs
    systemctl enable --now nginx
    setsebool -P httpd_can_network_connect 1 || true

    PUBLIC_IP=$(curl -s ifconfig.me)
    DOMAIN="${!PUBLIC_IP}.nip.io"

    cat <<NGINXCONF > /etc/nginx/conf.d/app.conf
    server {
        listen 80;
        server_name ${!DOMAIN};
        location / {
            proxy_pass http://${aws_instance.app.private_ip}:3000;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }
    NGINXCONF

    systemctl restart nginx
    python3 -m venv /opt/certbot/
    /opt/certbot/bin/pip install --upgrade pip certbot certbot-nginx
    ln -s /opt/certbot/bin/certbot /usr/bin/certbot
    certbot --nginx -d ${!DOMAIN} --non-interactive --agree-tos -m ${var.alert_email}
  EOF

  tags = {
    Name = "w3-nginx-server"
  }
}

resource "aws_eip_association" "nginx" {
  instance_id   = aws_instance.nginx.id
  allocation_id = aws_eip.nginx.id
}

# =========================================================
# 8. CloudWatch Log Group
# =========================================================
resource "aws_cloudwatch_log_group" "app" {
  name              = "/aws/ec2/bookcatalog-w3"
  retention_in_days = 7

  tags = {
    Name = "w3-app-log-group"
  }
}

# =========================================================
# 9. SNS Topic & Email Subscription
# =========================================================
resource "aws_sns_topic" "alarms" {
  name         = "w3-cloudwatch-alarms"
  display_name = "CloudWatch Alarms for BookCatalog"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# =========================================================
# 10. CloudWatch Alarms
# =========================================================

# Log-based alarm: Error keyword
resource "aws_cloudwatch_log_metric_filter" "errors" {
  name           = "w3-error-filter"
  log_group_name = aws_cloudwatch_log_group.app.name
  pattern        = "Error"

  metric_transformation {
    name          = "ErrorCount"
    namespace     = "WebAppMetrics"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "errors" {
  alarm_name          = "w3-ErrorAlarm"
  alarm_description   = "Level 1: Error Log Detected"
  metric_name         = "ErrorCount"
  namespace           = "WebAppMetrics"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = [aws_sns_topic.alarms.arn]
}

# CPU utilization alarm
resource "aws_cloudwatch_metric_alarm" "cpu" {
  alarm_name          = "w3-CPUAlarm"
  alarm_description   = "Level 2: High CPU Utilization (>80%)"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 1
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    InstanceId = aws_instance.app.id
  }
}

# EC2 status check alarm
resource "aws_cloudwatch_metric_alarm" "status_check" {
  alarm_name          = "w3-StatusCheckAlarm"
  alarm_description   = "Level 3: Server Down (Status Check Failed)"
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    InstanceId = aws_instance.app.id
  }
}

# RDS storage alarm
resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  alarm_name          = "w3-RDSStorageAlarm"
  alarm_description   = "RDS: Free storage space below 2GB"
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 2000000000
  comparison_operator = "LessThanThreshold"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.postgres.id
  }
}

# Nginx status check alarm
resource "aws_cloudwatch_metric_alarm" "nginx_status" {
  alarm_name          = "w3-NginxStatusCheckAlarm"
  alarm_description   = "Nginx: Server Down - all users cannot access the app"
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    InstanceId = aws_instance.nginx.id
  }
}
