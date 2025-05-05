terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 4.0"
        }
        docker = {
            source  = "kreuzwerker/docker"
            version = "~> 3.0"
        }
    }
    backend "s3" {
        bucket = "terra-state-bucket-ops"
        key = "waf-testing/terraform.tfstate"
        region = "us-east-1"
    }
}

provider "aws" {
    region = "us-east-1"
}

provider "docker" {
  registry_auth {
    address  = "${aws_ecr_repository.app.repository_url}"
    username = "AWS"
    password = data.aws_ecr_authorization_token.token.password
  }
}