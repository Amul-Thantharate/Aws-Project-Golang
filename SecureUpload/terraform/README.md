# GuardDuty S3 Malware Protection

This Terraform configuration sets up AWS GuardDuty with S3 malware protection for the SecureUpload project.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                           AWS Account                               │
│                                                                     │
│  ┌───────────────────┐        ┌───────────────────────────────┐     │
│  │                   │        │                               │     │
│  │  AWS GuardDuty    │◄───────┤  GuardDuty S3 Malware         │     │
│  │  Detector         │        │  Protection (Account-wide)     │     │
│  │                   │        │                               │     │
│  └───────────────────┘        └───────────────────────────────┘     │
│           │                                                         │
│           │                                                         │
│           ▼                                                         │
│  ┌───────────────────┐        ┌───────────────────────────────┐     │
│  │                   │        │                               │     │
│  │  IAM Role for     │◄───────┤  IAM Policy for S3            │     │
│  │  GuardDuty        │        │  Object Access                │     │
│  │                   │        │                               │     │
│  └───────────────────┘        └───────────────────────────────┘     │
│           │                                                         │
│           │                                                         │
│           ▼                                                         │
│  ┌───────────────────────────────────────────────────────────┐      │
│  │                                                           │      │
│  │                  S3 Bucket (Private)                      │      │
│  │                                                           │      │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐    │      │
│  │  │ Server-side │  │ Block Public│  │ Bucket          │    │      │
│  │  │ Encryption  │  │ Access      │  │ Ownership       │    │      │
│  │  └─────────────┘  └─────────────┘  └─────────────────┘    │      │
│  │                                                           │      │
│  └───────────────────────────────────────────────────────────┘      │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Features

- Enables GuardDuty with S3 malware protection at the account level
- Creates a secure S3 bucket for file uploads
- Configures proper IAM roles and permissions for GuardDuty to access S3 objects
- Implements security best practices (encryption, access controls)

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform installed (version 1.0.0 or later)

## Usage

1. Initialize Terraform:
   ```
   terraform init
   ```

2. Review the planned changes:
   ```
   terraform plan
   ```

3. Apply the configuration:
   ```
   terraform apply
   ```

4. To destroy the resources when no longer needed:
   ```
   terraform destroy
   ```

## Variables

You can customize the deployment by modifying the variables in `variables.tf` or by creating a `terraform.tfvars` file.

## Important Notes

- GuardDuty S3 malware protection scans objects as they are uploaded to S3
- The current configuration enables malware scanning for ALL buckets in the AWS account
- There are costs associated with GuardDuty and S3 usage
- The configuration follows AWS security best practices

## How It Works

1. GuardDuty monitors S3 data events (object-level API operations)
2. When objects are uploaded to any S3 bucket, GuardDuty analyzes them for malware
3. If malware is detected, GuardDuty generates a finding
4. The IAM role and policy allow GuardDuty to access objects in the S3 bucket
5. The S3 bucket is configured with security best practices:
   - Private ACL
   - Server-side encryption
   - Public access blocking
   - Proper bucket ownership controls
