variable "project_name" {
  description = "Name of the project"
  default     = "SecureCertAccess"
}

variable "ca_cert_path" {
  description = "Path to the CA certificate file"
  default     = "~/certs/ca.crt"
}

# IAM Role that will be assumed by workloads
resource "aws_iam_role" "roles_anywhere_role" {
  name = "${var.project_name}-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "rolesanywhere.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# Attach a policy to the role (example: read-only access to S3)
resource "aws_iam_role_policy_attachment" "role_policy" {
  role       = aws_iam_role.roles_anywhere_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Local file data source for CA certificate
data "local_file" "ca_cert" {
  filename = pathexpand(var.ca_cert_path)
}

# IAM Roles Anywhere Trust Anchor
resource "aws_rolesanywhere_trust_anchor" "ca_anchor" {
  name = "${var.project_name}-trust-anchor"
  
  source {
    source_data {
      x509_certificate_data = data.local_file.ca_cert.content
    }
    source_type = "CERTIFICATE_BUNDLE"
  }
}

# IAM Roles Anywhere Profile
resource "aws_rolesanywhere_profile" "workload_profile" {
  name = "${var.project_name}-profile"
  
  role_arns = [
    aws_iam_role.roles_anywhere_role.arn
  ]
}

