terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}


provider "aws" {
  alias  = "east"
  region = "us-east-1"
  # You can specify other provider arguments here like profile, etc.
}

provider "aws" {
  alias  = "west"
  region = "us-west-2"
  # You can specify other provider arguments here like profile, etc.
}
