#!/bin/bash

# Build Docker image
docker build -t your-docker-repo/waf-testing-app:latest .

# Push to Docker repository
docker push your-docker-repo/waf-testing-app:latest

# Initialize Terraform
terraform init

# Deploy infrastructure
terraform apply -auto-approve

# Get ALB DNS name
ALB_DNS=$(terraform output -raw alb_dns_name)

echo "Application deployed successfully!"
echo "Access your application at: http://$ALB_DNS"