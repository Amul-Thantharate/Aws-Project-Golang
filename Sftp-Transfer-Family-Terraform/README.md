# AWS SFTP Transfer Family with Terraform 🚀

This project sets up a secure SFTP server using AWS Transfer Family, managed with Terraform. It provides a fully managed SFTP service that automatically scales based on your needs.

## Features 🌟

- Secure SFTP server setup using AWS Transfer Family
- S3 bucket integration for file storage
- IAM roles and policies for secure access
- Service-managed user authentication
- Optional CloudWatch logging
- Version control for S3 objects
- Server-side encryption for stored files
- Complete bucket access control

## Prerequisites 📋

- AWS Account
- [Terraform](https://www.terraform.io/downloads.html) (v1.0.0 or later)
- AWS CLI configured with appropriate credentials
- SSH key pair for SFTP authentication

## Architecture 🏗️

The infrastructure includes:
- AWS Transfer Family SFTP Server
- S3 Bucket for file storage
- IAM roles and policies
- AWS Secrets Manager for credentials
- CloudWatch Logs (optional)

## Quick Start 🚦

1. **Clone the repository**
```bash
git clone https://github.com/Amul-Thantharate/Aws-Project-Golang-Terraform.git
cd Aws-Project-Golang-Terraform/Sftp-Transfer-Family-Terraform
```

2. **Configure variables**
Copy `terraform.tfvars.example` to `terraform.tfvars` and update the values:
```hcl
bucket_name          = "your-unique-bucket-name"
password_secret_name = "your-secret-name"
tags = {
    Environment = "dev"
    Project     = "aws-sftp-transfer"
}
```

3. **Initialize Terraform**
```bash
terraform init
```

4. **Deploy the infrastructure**
```bash
terraform plan
terraform apply
```

## Configuration Options 🔧

| Variable | Description | Default |
|----------|-------------|---------|
| `aws_region` | AWS region to deploy to | us-east-1 |
| `bucket_name` | S3 bucket name for SFTP | Required |
| `password_secret_name` | Secret name in Secrets Manager | Required |
| `transfer_username` | SFTP username | sftpuser |
| `enable_logging` | Enable CloudWatch logging | false |
| `force_destroy_bucket` | Allow bucket deletion with contents | false |
| `endpoint_type` | Server endpoint type | PUBLIC |
| `protocols` | Transfer protocols | ["SFTP"] |

## Security Features 🔐

- Server-side encryption (SSE) enabled by default
- Public access blocked on S3 bucket
- IAM roles with least privilege access
- SSH key-based authentication
- Security policy compliance

## Outputs 📤

After successful deployment, you'll receive:
- SFTP server endpoint
- Transfer server ID
- S3 bucket ARN
- Transfer user name

## Connecting to the SFTP Server 🔌

1. Use the SSH key pair for authentication
2. Connect using any SFTP client with:
   - Host: (server endpoint from outputs)
   - Username: (configured username)
   - SSH Key: The private key file

Example connection:
```bash
sftp -i /path/to/private/key username@server-endpoint
```

## Maintenance 🛠️

### Updating
1. Modify the terraform configuration as needed
2. Run:
```bash
terraform plan
terraform apply
```

### Cleanup
To destroy the infrastructure:
```bash
terraform destroy
```

## Best Practices ✨

- Regularly rotate SSH keys
- Enable logging in production
- Use version control for configuration
- Implement proper backup strategies
- Monitor AWS CloudWatch metrics

## Troubleshooting 🔍

Common issues and solutions:
1. **Connection refused**
   - Verify security group rules
   - Check SSH key permissions

2. **Access denied**
   - Verify IAM roles and policies
   - Check user permissions in Transfer Family

3. **Upload/Download issues**
   - Verify S3 bucket permissions
   - Check IAM policy attachments

## Contributing 🤝

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## Support 💬

For support, please open an issue in the repository or contact the maintainers.
