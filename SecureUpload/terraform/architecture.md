# GuardDuty S3 Malware Protection Architecture

## Architecture Diagram

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

## Data Flow

1. **File Upload**: A user uploads a file to the S3 bucket
2. **S3 Event**: S3 generates an object-level API event
3. **GuardDuty Monitoring**: GuardDuty monitors these events
4. **Malware Scanning**: GuardDuty scans the uploaded object for malware
5. **Finding Generation**: If malware is detected, GuardDuty generates a finding

## Component Details

### AWS GuardDuty Detector
- Primary GuardDuty resource that enables the service
- Configured with 15-minute finding publishing frequency
- Enables S3 logs and malware protection features

### GuardDuty S3 Malware Protection
- Account-wide protection for all S3 buckets
- Scans objects as they are uploaded
- Detects various types of malware

### IAM Role and Policy
- Allows GuardDuty to access S3 objects
- Limited permissions (GetObject, ListBucket)
- Scoped to the specific S3 bucket

### S3 Bucket
- Private access control
- Server-side encryption with AES-256
- Public access blocking
- Proper bucket ownership controls

## Security Considerations

- All S3 objects are encrypted at rest
- No public access to the bucket
- Least privilege IAM permissions
- GuardDuty findings can be integrated with other security services
