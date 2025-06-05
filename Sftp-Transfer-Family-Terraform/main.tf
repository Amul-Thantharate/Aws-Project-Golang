data "aws_caller_identity" "current" {}

# Fetch the password from AWS Secrets Manager
data "aws_secretsmanager_secret_version" "password" {
  secret_id = var.password_secret_name
}

resource "aws_s3_bucket" "transfer_bucket" {
  bucket  = var.bucket_name
  # force_destroy is important for allowing the bucket to be deleted even if it contains objects.
  force_destroy = var.force_destroy_bucket

  tags = merge(var.tags, {
    Name = "Transfer Bucket"
  })
}

resource "aws_s3_bucket_versioning" "transfer_bucket" {
  bucket = aws_s3_bucket.transfer_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "transfer_bucket" {
  bucket = aws_s3_bucket.transfer_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" # Use AES256 encryption
    }
  }
}

# Block public access to the S3 bucket
resource "aws_s3_bucket_public_access_block" "transfer_bucket" {
  bucket = aws_s3_bucket.transfer_bucket.id

  block_public_acls  = true
  block_public_policy   = true
  ignore_public_acls    = true
  restrict_public_buckets = true
}

# Create the IAM role for the Transfer service to access S3
resource "aws_iam_role" "transfer_role" {
  name = "transfer-role-${var.bucket_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = {
          Service = "transfer.amazonaws.com" # Allow Transfer service to assume this role
        },
        Effect = "Allow"
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "Transfer Role"
  })
}

resource "aws_iam_policy" "transfer_policy" {
  name  = "transfer-policy-${var.bucket_name}"
  description = "Allows SFTP to access S3 and Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetObjectVersion", # Added GetObjectVersion
          "s3:GetBucketLocation"  # Added GetBucketLocation
        ],
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.transfer_bucket.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.transfer_bucket.bucket}/*"
        ],
        Effect = "Allow"
      },
      {
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ],
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.password_secret_name}*",
        Effect  = "Allow"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "transfer_role_attachment" {
  role  = aws_iam_role.transfer_role.name
  policy_arn = aws_iam_policy.transfer_policy.arn
}

resource "aws_iam_role" "transfer_logging_role" {
  count = var.enable_logging ? 1 : 0 # Only create if logging is enabled

  name = "transfer-logging-role-${var.bucket_name}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = {
          Service = "transfer.amazonaws.com" # Allow Transfer to assume this role
        },
        Effect = "Allow"
      }
    ]
  })
}

resource "aws_iam_policy" "transfer_logging_policy" {
  count = var.enable_logging ? 1 : 0 # Only create if logging is enabled

  name  = "transfer-logging-policy-${var.bucket_name}"
  description = "Allows Transfer Family to write logs"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ],
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/transfer/*",
        Effect  = "Allow"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "transfer_logging_attachment" {
  count = var.enable_logging ? 1 : 0 # Only create if logging is enabled

  role  = aws_iam_role.transfer_logging_role[count.index].name
  policy_arn = aws_iam_policy.transfer_logging_policy[count.index].arn
}

# Create the AWS Transfer Family server
resource "aws_transfer_server" "transfer_server" {
  identity_provider_type = "SERVICE_MANAGED"
  endpoint_type          = var.endpoint_type
  protocols              = ["SFTP"]
  security_policy_name   = var.security_policy_name
  domain                 = "S3"
  logging_role           = var.enable_logging ? aws_iam_role.transfer_logging_role[0].arn : null

  tags = merge(var.tags, {
    Name = "Transfer Server"
  })
}
# Create the Transfer Family user
resource "aws_transfer_user" "transfer_user" {
  server_id      = aws_transfer_server.transfer_server.id
  user_name      = var.transfer_username
  role           = aws_iam_role.transfer_role.arn
  home_directory = "/${var.bucket_name}"

  tags = merge(var.tags, {
    Name = "Transfer User"
  })
}


resource "aws_transfer_ssh_key" "transfer_user_key" {
  server_id = aws_transfer_server.transfer_server.id
  user_name = aws_transfer_user.transfer_user.user_name
  body      = file("${path.module}/aws.pub")  
}