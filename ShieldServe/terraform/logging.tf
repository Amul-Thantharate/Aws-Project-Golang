# S3 Bucket for WAF Logs
resource "aws_s3_bucket" "waf_logs" {
  bucket = "waf-logs-${random_string.suffix.result}"
  force_destroy = true
}

# Generate a random suffix for globally unique S3 bucket name
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# S3 Bucket Policy for WAF Logs
resource "aws_s3_bucket_policy" "waf_logs_policy" {
  bucket = aws_s3_bucket.waf_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowWAFLogging"
        Effect    = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.waf_logs.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid       = "AllowWAFLoggingAclCheck"
        Effect    = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.waf_logs.arn
      }
    ]
  })
}

# CloudWatch Log Group for WAF Logs
resource "aws_cloudwatch_log_group" "waf_logs" {
  name              = "/aws/waf/logs/security-acl"
  retention_in_days = 30
}

# IAM Role for WAF Logging to CloudWatch
resource "aws_iam_role" "waf_logging_role" {
  name = "waf-logging-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "firehose.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for WAF Logging
resource "aws_iam_role_policy" "waf_logging_policy" {
  name   = "waf-logging-policy"
  role   = aws_iam_role.waf_logging_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetBucketLocation",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.waf_logs.arn,
          "${aws_s3_bucket.waf_logs.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:PutLogEvents",
          "logs:CreateLogStream",
          "logs:CreateLogGroup"
        ]
        Resource = "${aws_cloudwatch_log_group.waf_logs.arn}:*"
      }
    ]
  })
}

# Kinesis Firehose Delivery Stream for WAF Logs
resource "aws_kinesis_firehose_delivery_stream" "waf_logs" {
  name        = "aws-waf-logs-security-acl"
  destination = "extended_s3"
  
  extended_s3_configuration {
    role_arn   = aws_iam_role.waf_logging_role.arn
    bucket_arn = aws_s3_bucket.waf_logs.arn
    prefix     = "waf-logs/"
    buffering_size     = 5
    buffering_interval = 300
    compression_format = "GZIP"
    
    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.waf_logs.name
      log_stream_name = "S3Delivery"
    }
  }
}

# WAF Logging Configuration
resource "aws_wafv2_web_acl_logging_configuration" "waf_logging" {
  log_destination_configs = [aws_kinesis_firehose_delivery_stream.waf_logs.arn]
  resource_arn            = aws_wafv2_web_acl.main.arn
  
  redacted_fields {
    single_header {
      name = "authorization"
    }
  }
  
  redacted_fields {
    single_header {
      name = "cookie"
    }
  }
}

# CloudWatch Dashboard for WAF Metrics
resource "aws_cloudwatch_dashboard" "waf_dashboard" {
  dashboard_name = "WAF-Security-Dashboard"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/WAFV2", "BlockedRequests", "WebACL", "security-acl", "Region", var.region],
            ["AWS/WAFV2", "AllowedRequests", "WebACL", "security-acl", "Region", var.region]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "WAF Requests (Blocked vs Allowed)"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/WAFV2", "CountedRequests", "WebACL", "security-acl", "Rule", "SQLi-Detection", "Region", var.region],
            ["AWS/WAFV2", "CountedRequests", "WebACL", "security-acl", "Rule", "XSS-Detection", "Region", var.region],
            ["AWS/WAFV2", "CountedRequests", "WebACL", "security-acl", "Rule", "LFI-Detection", "Region", var.region],
            ["AWS/WAFV2", "CountedRequests", "WebACL", "security-acl", "Rule", "BlockAdminPaths", "Region", var.region],
            ["AWS/WAFV2", "CountedRequests", "WebACL", "security-acl", "Rule", "BlockScanners", "Region", var.region]
          ]
          view    = "timeSeries"
          stacked = true
          region  = var.region
          title   = "WAF Rule Hits by Type"
          period  = 300
        }
      }
    ]
  })
}

# CloudWatch Alarms for WAF
resource "aws_cloudwatch_metric_alarm" "waf_high_blocked_requests" {
  alarm_name          = "WAF-HighBlockedRequests"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = 300
  statistic           = "Sum"
  threshold           = 100
  alarm_description   = "This alarm triggers when the WAF blocks more than 100 requests in 5 minutes"
  
  dimensions = {
    WebACL = "security-acl"
    Region = var.region
  }
}

# Output the S3 bucket and CloudWatch log group information
output "waf_logs_s3_bucket" {
  value = aws_s3_bucket.waf_logs.bucket
}

output "waf_logs_cloudwatch_log_group" {
  value = aws_cloudwatch_log_group.waf_logs.name
}
