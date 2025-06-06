# 🚀 AWS Projects with Golang And Terraform

Welcome to our collection of AWS projects built with Golang! 🐙 This repository contains multiple AWS integrations and services implemented using the Go programming language. Golang, known for its simplicity, efficiency, and strong concurrency support, makes it an excellent choice for building cloud-native applications. Combined with Terraform, the industry-leading Infrastructure as Code (IaC) tool, we can create, manage, and version our cloud infrastructure with declarative configuration files.

## 📋 Table of Contents

- [Overview](#overview)
- [Projects](#projects)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Contributing](#contributing)
- [License](#license)

## 🌐 Overview

This repository showcases various AWS projects implemented using Golang, demonstrating best practices for cloud-native development and AWS service integration. Each project is designed to be modular, scalable, and follows AWS best practices.

## 📦 Projects

### 1. ShieldServe 🛡️
A security-focused web application infrastructure deployed on AWS. It provides robust protection against common web vulnerabilities (SQLi, XSS, LFI) through AWS WAF with custom responses, while offering high availability via auto-scaling and comprehensive security logging. Features include:
- Custom WAF responses for different attack types
- Comprehensive logging with S3, CloudWatch, and Kinesis Firehose
- Security dashboard for real-time monitoring
- Containerized application with Docker and ECR
- Auto-scaling EC2 instances with t3.micro for optimal performance

### 2. PixlFlow 🎨
PixlFlow is a Go application that processes images with various transformations including blurring, upscaling, and pixelation effects. It can run locally or be deployed as an AWS Lambda function triggered by S3 uploads.

### 3. Lambda X-Ray Event 📊
This project is an AWS Lambda function that demonstrates how to use AWS X-Ray for tracing and monitoring HTTP requests. The function fetches random dog images from the Dog API, saves them to an S3 bucket, and returns the image URL. 🚀

### 4. GoServerlessCRUD (DynamoDB) 📊
GoServerlessCRUD is a serverless backend application written in Go that provides a simple and scalable CRUD (Create, Read, Update, Delete) API. It uses AWS Lambda for serverless compute, API Gateway for HTTP endpoints, and DynamoDB for persistent NoSQL storage. This project is ideal for building fast, low-maintenance APIs with minimal infrastructure overhead.

### 5. Terraform Transit Gateway Peering 🌉
This project demonstrates how to use Terraform to create a Transit Gateway Peering between two VPCs in different AWS accounts. It's a great way to connect resources across multiple AWS accounts and regions.

### 6. Sftp-Transfer-Family-Terraform
This project sets up a secure SFTP server using AWS Transfer Family, managed with Terraform. It provides a fully managed SFTP service that automatically scales based on your needs.

### 7. SecureCertAccess 🔒
IAM Roles Anywhere allows on-premises servers, containers, and applications to use X.509 certificates to obtain temporary AWS credentials. This eliminates the need to manage long-term AWS credentials outside of AWS.

### 8. SecureUpload 🛡️📤
A secure file upload solution using AWS S3 with GuardDuty malware protection. It includes a Go web application for handling file uploads and Terraform configurations for setting up the required AWS infrastructure with security best practices. Features include:
- GuardDuty malware scanning for all S3 uploads
- Server-side encryption for all stored files
- Public access blocking for S3 bucket
- Least privilege IAM permissions
- Malware detection and alerting

## 🔧️ Prerequisites

Before you begin, ensure you have the following installed:

- Go 1.20+ 🐙
- AWS CLI v2 🔐
- Docker 🐋 (for containerized deployments)
- Git 🌱
- Terraform v1.0.0+ 🛠️ (for infrastructure as code)

### AWS Setup Requirements

1. AWS Account 🔐
2. IAM User with appropriate permissions 🛡️
3. AWS Access Key ID and Secret Access Key 🔑
4. AWS Region Configuration 🗺️

## 🤝 Contributing

We welcome contributions! Please feel free to:

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- Thanks to the AWS team for their amazing services and documentation
- Special thanks to the Go community for their support and contributions

---

Built with ❤️ by Amul Thantharate
