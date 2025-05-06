terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 4.0"
        }
    }
    backend "s3" {
        bucket = "terra-state-bucket-ops"
        key = "pixelFlow/terraform.tfstate"
        region = "us-east-1"
    }
}

provider "aws" {
    region = var.region
}