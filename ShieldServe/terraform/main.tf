# 1. Create ECR Repository
resource "aws_ecr_repository" "app" {
  name                 = "security-app"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

# 2. Build and Push Docker Image
data "aws_ecr_authorization_token" "token" {}

resource "null_resource" "docker_build_push" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<EOF
      cd .. && \
      docker build -t ${aws_ecr_repository.app.repository_url}:latest . && \
      aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${aws_ecr_repository.app.repository_url} && \
      docker push ${aws_ecr_repository.app.repository_url}:latest
    EOF
  }

  depends_on = [aws_ecr_repository.app]
}

# 3. WAF with Custom Responses
resource "aws_wafv2_web_acl" "main" {
  name        = "security-acl"
  scope       = "REGIONAL"
  description = "Blocks SQLi/XSS/LFI with custom messages"

  default_action {
    allow {}
  }

  # Custom Response Templates
  custom_response_body {
    key          = "sql_block"
    content      = file("${path.module}/templates/sql_block.html")
    content_type = "TEXT_HTML"
  }

  custom_response_body {
    key          = "xss_block"
    content      = file("${path.module}/templates/xss_block.html")
    content_type = "TEXT_HTML"
  }

  custom_response_body {
    key          = "lfi_block"
    content      = file("${path.module}/templates/lfi_block.html")
    content_type = "TEXT_HTML"
  }

  # Rule 1: SQL Injection Detection
  rule {
    name     = "SQLi-Detection"
    priority = 1

    action {
      block {
        custom_response {
          response_code            = 403
          custom_response_body_key = "sql_block"
          response_header {
            name  = "X-Blocked-Reason"
            value = "SQL Injection Detected"
          }
        }
      }
    }

    statement {
      byte_match_statement {
        field_to_match {
          all_query_arguments {}
        }
        positional_constraint = "CONTAINS"
        search_string         = "'"
        text_transformation {
          priority = 1
          type     = "URL_DECODE"
        }
        text_transformation {
          priority = 2
          type     = "HTML_ENTITY_DECODE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "SQLi-Detection"
      sampled_requests_enabled   = true
    }
  }

  # Rule 2: XSS Detection
  rule {
    name     = "XSS-Detection"
    priority = 2

    action {
      block {
        custom_response {
          response_code            = 403
          custom_response_body_key = "xss_block"
          response_header {
            name  = "X-Blocked-Reason"
            value = "XSS Attempt Blocked"
          }
        }
      }
    }

    statement {
      byte_match_statement {
        field_to_match {
          body {}
        }
        positional_constraint = "CONTAINS"
        search_string         = "<script>"
        text_transformation {
          priority = 1
          type     = "URL_DECODE"
        }
        text_transformation {
          priority = 2
          type     = "HTML_ENTITY_DECODE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "XSS-Detection"
      sampled_requests_enabled   = true
    }
  }

  # Rule 3: Path Traversal Detection
  rule {
    name     = "LFI-Detection"
    priority = 3

    action {
      block {
        custom_response {
          response_code            = 403
          custom_response_body_key = "lfi_block"
          response_header {
            name  = "X-Blocked-Reason"
            value = "Path Traversal Detected"
          }
        }
      }
    }

    statement {
      byte_match_statement {
        field_to_match {
          uri_path {}
        }
        positional_constraint = "CONTAINS"
        search_string         = "../"
        text_transformation {
          priority = 1
          type     = "URL_DECODE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "LFI-Detection"
      sampled_requests_enabled   = true
    }
  }

  # Rule 4: Block Admin Paths
  rule {
    name     = "BlockAdminPaths"
    priority = 4

    action {
      block {
        custom_response {
          response_code = 403
          response_header {
            name  = "X-Blocked-Reason"
            value = "Admin access restricted"
          }
        }
      }
    }

    statement {
      byte_match_statement {
        field_to_match {
          uri_path {}
        }
        positional_constraint = "STARTS_WITH"
        search_string         = "/admin"
        text_transformation {
          priority = 0
          type     = "LOWERCASE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BlockAdminPaths"
      sampled_requests_enabled   = true
    }
  }

  # Rule 5: Block Security Scanners
  rule {
    name     = "BlockScanners"
    priority = 5

    action {
      block {
        custom_response {
          response_code = 403
          response_header {
            name  = "X-Blocked-Reason"
            value = "Security scanner detected"
          }
        }
      }
    }

    statement {
      byte_match_statement {
        field_to_match {
          single_header {
            name = "user-agent"
          }
        }
        positional_constraint = "CONTAINS"
        search_string         = "sqlmap"
        text_transformation {
          priority = 0
          type     = "LOWERCASE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BlockScanners"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "security-acl"
    sampled_requests_enabled   = true
  }
}

# Variables and Outputs
variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}

output "alb_dns_name" {
  value = aws_lb.app.dns_name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

# 4. ALB Setup
resource "aws_lb" "app" {
  name               = "security-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb.id]
  subnets            = aws_subnet.public[*].id
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.app.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# 5. WAF Association
resource "aws_wafv2_web_acl_association" "main" {
  resource_arn = aws_lb.app.arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}

# Supporting Resources
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = "${var.region}${count.index == 0 ? "a" : "b"}"
  map_public_ip_on_launch = true
}

resource "aws_security_group" "lb" {
  name   = "allow-http"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb_target_group" "app" {
  name     = "security-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

# 6. EC2 Instance Creation with Auto Scaling Group
resource "aws_security_group" "instance" {
  name   = "app-instance-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.lb.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict this in production
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Only allow outbound HTTPS
  }
}

# EC2 IAM Role for ECR Access
resource "aws_iam_role" "ec2_ecr_role" {
  name = "ec2-ecr-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy" "ecr_access" {
  name = "ecr-access"
  role = aws_iam_role.ec2_ecr_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "ecr:GetAuthorizationToken"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-ecr-profile"
  role = aws_iam_role.ec2_ecr_role.name
}

# AMI for EC2 instances
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

# Create Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

# Associate Route Table with Subnets
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Launch Template for Auto Scaling Group
resource "aws_launch_template" "app" {
  name_prefix   = "security-app-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }
  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.instance.id]
  }
  user_data = base64encode(<<-EOF
    #!/bin/bash
    amazon-linux-extras install docker -y
    systemctl start docker
    systemctl enable docker
    $(aws ecr get-login-password --region ${var.region}) | docker login --username AWS --password-stdin ${aws_ecr_repository.app.repository_url}
    docker pull ${aws_ecr_repository.app.repository_url}:latest
    docker run -d -p 8080:8080 ${aws_ecr_repository.app.repository_url}:latest
  EOF
  )

  depends_on = [null_resource.docker_build_push, aws_internet_gateway.main]
}

# Auto Scaling Group
resource "aws_autoscaling_group" "app" {
  desired_capacity    = 2
  max_size            = 4
  min_size            = 2
  vpc_zone_identifier = aws_subnet.public[*].id
  target_group_arns   = [aws_lb_target_group.app.arn]

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }
}