variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "bucket_name" {
  type        = string
  description = "S3 bucket name for SFTP"
}

variable "password_secret_name" {
  type        = string
  description = "Secret name in Secrets Manager"
}

variable "transfer_username" {
  type        = string
  default     = "sftpuser"
}

variable "enable_logging" {
  type    = bool
  default = false
}

variable "force_destroy_bucket" {
  type    = bool
  default = false
}

variable "identity_provider_type" {
  type    = string
  default = "SERVICE_MANAGED"
}

variable "endpoint_type" {
  type    = string
  default = "PUBLIC"
}

variable "protocols" {
  type    = list(string)
  default = ["SFTP"]
}

variable "security_policy_name" {
  type    = string
  default = "TransferSecurityPolicy-2022-03"
}

variable "tags" {
  type    = map(string)
  default = {}
}
