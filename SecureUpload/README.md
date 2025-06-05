# 🚀 SecureUpload Project with GuardDuty Protection

## 📋 Overview

This project provides a secure file upload solution using AWS S3 with GuardDuty malware protection. It includes a Go application for handling file uploads and Terraform configurations for setting up the required AWS infrastructure with security best practices.

## 🏗️ Architecture

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
│           ▲                                                         │
│           │                                                         │
│           │                                                         │
│  ┌───────────────────────────────────────────────────────────┐      │
│  │                                                           │      │
│  │                  Go Web Application                       │      │
│  │                                                           │      │
│  └───────────────────────────────────────────────────────────┘      │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## 🔧 Components

### 1. Go Web Application 🖥️
- Simple web interface for file uploads
- Secure handling of file uploads to S3
- Static file serving

### 2. AWS Infrastructure (Terraform) ☁️
- **GuardDuty**: Malware protection for S3 uploads
- **S3 Bucket**: Secure storage with encryption and access controls
- **IAM Roles**: Proper permissions for GuardDuty to access S3

## 🛡️ Security Features

- ✅ GuardDuty malware scanning for all S3 uploads
- 🔒 Server-side encryption for all stored files
- 🚫 Public access blocking for S3 bucket
- 🔐 Least privilege IAM permissions
- 🛑 Malware detection and alerting

## 🚀 Getting Started

### Prerequisites

- Go 1.16+ installed
- AWS CLI configured with appropriate credentials
- Terraform 1.0.0+ installed

### Setting Up Infrastructure

1. Navigate to the terraform directory:
   ```
   cd terraform
   ```

2. Initialize Terraform:
   ```
   terraform init
   ```

3. Apply the configuration:
   ```
   terraform plan
   terraform apply
   ```

4. Note the S3 bucket name from the outputs

### Running the Application

1. Update the S3 bucket name in the application configuration (if needed)

2. Run the Go application:
   ```
   go run main.go
   ```

3. Access the application at http://localhost:8080

## 📁 Project Structure

```
SecureUpload/
├── main.go                 # Go application entry point
├── static/                 # Static web files
├── go.mod                  # Go module definition
├── go.sum                  # Go dependencies
└── terraform/              # Terraform configuration
    ├── main.tf             # Main Terraform configuration
    ├── variables.tf        # Variable definitions
    ├── terraform.tfvars    # Variable values
    ├── README.md           # Terraform documentation
    └── architecture.md     # Architecture documentation
```

## 🔍 How It Works

1. 🌐 User accesses the web application
2. 📤 User selects and uploads a file
3. 🚀 Go application sends the file to S3
4. 🔍 GuardDuty automatically scans the file for malware
5. ⚠️ If malware is detected, GuardDuty generates a finding
6. 🔒 Files are stored securely with encryption

## 🛠️ Development

### Adding New Features

1. Modify the Go application in `main.go`
2. Update the web interface in the `static` directory
3. Add new AWS resources in the Terraform configuration as needed

### Testing

Run the application locally and test file uploads:
```
go run main.go
```

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- AWS for providing secure cloud infrastructure
- The Go community for excellent libraries and tools
- Terraform for infrastructure as code capabilities
