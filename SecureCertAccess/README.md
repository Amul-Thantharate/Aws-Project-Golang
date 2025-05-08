# 🔐 SecureCertAccess: AWS IAM Roles Anywhere with OpenSSL

This guide demonstrates how to use AWS IAM Roles Anywhere with OpenSSL certificates to enable workloads outside of AWS to obtain temporary AWS credentials.

## 🌟 Overview

IAM Roles Anywhere allows on-premises servers, containers, and applications to use X.509 certificates to obtain temporary AWS credentials. This eliminates the need to manage long-term AWS credentials outside of AWS.

## ✅ Prerequisites

- 🛠️ AWS CLI installed and configured
- 🔒 OpenSSL installed
- 👮 Permissions to create IAM roles and trust anchors
- 🏗️ Terraform installed (for automated deployment)

## 📝 Manual Setup Steps

### 1️⃣ Create a Certificate Authority (CA)

First, create a private key for your CA:

```bash
openssl genrsa -out ca.key 2048
```

Create a self-signed CA certificate:

```bash
openssl req -new -x509 -sha256 -key ca.key -out ca.crt -days 365 -subj "/CN=My Private CA/O=My Organization/C=US"
```

### 2️⃣ Create a Certificate for Your Workload

Generate a private key for your workload:

```bash
openssl genrsa -out workload.key 2048
```

Create a Certificate Signing Request (CSR):

```bash
openssl req -new -key workload.key -out workload.csr -subj "/CN=my-workload/O=My Organization/C=US"
```

Sign the CSR with your CA:

```bash
openssl x509 -req -in workload.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out workload.crt -days 365 -sha256
```

### 3️⃣ Set Up IAM Roles Anywhere

Create a trust anchor in IAM Roles Anywhere using your CA certificate:

```bash
aws rolesanywhere create-trust-anchor \
  --name "my-trust-anchor" \
  --source "sourceData={x509CertificateData=$(cat ca.crt)},sourceType=CERTIFICATE_BUNDLE" \
  --region us-east-1
```

Create a profile in IAM Roles Anywhere:

```bash
aws rolesanywhere create-profile \
  --name "my-profile" \
  --role-arns "arn:aws:iam::123456789012:role/MyRoleAnywhereRole" \
  --region us-east-1
```

### 4️⃣ Create an IAM Role with Trust Policy

Create an IAM role with a trust policy that allows IAM Roles Anywhere to assume it:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "rolesanywhere.amazonaws.com"
      },
      "Action": [
        "sts:AssumeRole",
        "sts:TagSession"
      ],
      "Condition": {
        "StringEquals": {
          "aws:SourceAccount": "123456789012"
        },
        "ArnEquals": {
          "aws:SourceArn": "arn:aws:rolesanywhere:us-east-1:123456789012:trust-anchor/abcdef1234567890"
        }
      }
    }
  ]
}
```

### 5️⃣ Install the AWS Roles Anywhere Credential Helper

Download and install the credential helper:

```bash
curl -o aws_signing_helper https://s3.amazonaws.com/roles-anywhere-credential-helper/latest/aws_signing_helper-linux-amd64
chmod +x aws_signing_helper
sudo mv aws_signing_helper /usr/local/bin/
```

### 6️⃣ Obtain Temporary Credentials

Use the credential helper to obtain temporary credentials:

```bash
aws_signing_helper credential-process \
  --certificate workload.crt \
  --private-key workload.key \
  --trust-anchor-arn arn:aws:rolesanywhere:us-east-1:123456789012:trust-anchor/abcdef1234567890 \
  --profile-arn arn:aws:rolesanywhere:us-east-1:123456789012:profile/abcdef1234567890 \
  --role-arn arn:aws:iam::123456789012:role/MyRoleAnywhereRole
```

### 7️⃣ Configure AWS CLI to Use the Credential Helper

Add this to your `~/.aws/config` file:

```
[profile roles-anywhere]
credential_process = aws_signing_helper credential-process --certificate /path/to/workload.crt --private-key /path/to/workload.key --trust-anchor-arn arn:aws:rolesanywhere:us-east-1:123456789012:trust-anchor/abcdef1234567890 --profile-arn arn:aws:rolesanywhere:us-east-1:123456789012:profile/abcdef1234567890 --role-arn arn:aws:iam::123456789012:role/MyRoleAnywhereRole
```

Then use the profile:

```bash
aws s3 ls --profile roles-anywhere
```

## 🤖 Automated Terraform Deployment

This project includes Terraform scripts to automate the entire setup process.

### Files Structure

- `main.tf` - Core infrastructure setup (IAM role, trust anchor, profile)
- `certificates.tf` - Certificate generation and credential helper installation

### Deployment Steps

1. Initialize Terraform:
   ```bash
   terraform init
   ```

2. Apply the configuration:
   ```bash
   terraform apply
   ```

3. After successful deployment, Terraform will output:
   - Trust anchor ARN
   - Profile ARN
   - Role ARN
   - Ready-to-use credential helper command
   - AWS CLI profile configuration

4. Add the generated AWS CLI profile to your `~/.aws/config` file

### Customization

You can customize the deployment by modifying the variables in `main.tf`:

```hcl
variable "project_name" {
  description = "Name of the project"
  default     = "SecureCertAccess"
}

variable "ca_cert_path" {
  description = "Path to the CA certificate file"
  default     = "~/certs/ca.crt"
}
```

## 🛡️ Security Considerations

- 🔑 Store private keys securely
- 🔄 Implement certificate rotation
- ⏱️ Use appropriate certificate validity periods
- 🏢 Consider using a commercial or AWS Private CA for production environments

## 🔍 Troubleshooting

- 📋 Verify certificate chain validity
- 🔎 Check IAM role trust policy
- 🔐 Ensure proper permissions on the IAM role
- 🏷️ Verify the certificate subject matches what's expected by IAM Roles Anywhere

## 📚 Additional Resources

- [IAM Roles Anywhere Documentation](https://docs.aws.amazon.com/rolesanywhere/latest/userguide/introduction.html)
- [AWS Security Blog: Secure workloads outside AWS using IAM Roles Anywhere](https://aws.amazon.com/blogs/security/secure-workloads-outside-aws-using-iam-roles-anywhere/)
- [OpenSSL Documentation](https://www.openssl.org/docs/)
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
