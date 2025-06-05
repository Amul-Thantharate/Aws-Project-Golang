provider "aws" {
  region = var.aws_region
}

# Enable GuardDuty
resource "aws_guardduty_detector" "main" {
  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"
  
  datasources {
    s3_logs {
      enable = true
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
      scan_s3_objects {
        enable = true
      }
    }
  }

  tags = {
    Name        = "${var.project_name}-guardduty-detector"
    Environment = var.environment
  }
}

# Create an S3 bucket for file uploads with malware protection
resource "aws_s3_bucket" "upload_bucket" {
  bucket = "${var.project_name}-${var.environment}-uploads"

  tags = {
    Name        = "${var.project_name}-${var.environment}-uploads"
    Environment = var.environment
  }
}

# Configure bucket ownership controls
resource "aws_s3_bucket_ownership_controls" "upload_bucket" {
  bucket = aws_s3_bucket.upload_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Configure bucket ACL
resource "aws_s3_bucket_acl" "upload_bucket" {
  depends_on = [aws_s3_bucket_ownership_controls.upload_bucket]
  bucket     = aws_s3_bucket.upload_bucket.id
  acl        = "private"
}

# Enable server-side encryption for the bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "upload_bucket" {
  bucket = aws_s3_bucket.upload_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access to the bucket
resource "aws_s3_bucket_public_access_block" "upload_bucket" {
  bucket                  = aws_s3_bucket.upload_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Create an IAM role for GuardDuty to access S3
resource "aws_iam_role" "guardduty_s3_role" {
  name = "${var.project_name}-guardduty-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "guardduty.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-guardduty-s3-role"
    Environment = var.environment
  }
}

# Attach policy to allow GuardDuty to scan S3 objects
resource "aws_iam_role_policy" "guardduty_s3_policy" {
  name = "${var.project_name}-guardduty-s3-policy"
  role = aws_iam_role.guardduty_s3_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
        ]
        Effect   = "Allow"
        Resource = [
          aws_s3_bucket.upload_bucket.arn,
          "${aws_s3_bucket.upload_bucket.arn}/*"
        ]
      }
    ]
  })
}

# Output the GuardDuty detector ID and S3 bucket name
output "guardduty_detector_id" {
  value = aws_guardduty_detector.main.id
}

output "s3_bucket_name" {
  value = aws_s3_bucket.upload_bucket.bucket
}
