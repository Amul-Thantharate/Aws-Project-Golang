#!/bin/bash

# Attach the policy to an IAM role:
aws iam create-role --role-name lambda-s3-role --assume-role-policy-document file://trust-policy.json

# Attach the permissions to the role:

aws iam put-role-policy --role-name lambda-s3-role --policy-name LambdaS3Policy --policy-document file://lambda-s3-policy.json

GOOS=linux GOARCH=amd64 go build -o bootstrap 
zip -r function.zip bootstrap

# Create Lambda Function
aws lambda create-function \
    --function-name image-processing-lambda \
    --zip-file fileb://function.zip \
    --handler main \
    --runtime go1.x \
    --role arn:aws:iam::<account-id>:role/lambda-s3-role \
    --environment Variables="{SOURCE_BUCKET=source-bucket-name,DEST_BUCKET=destination-bucket-name}" \
    --timeout 15 \
    --memory-size 512


# Set up the S3 Trigger
aws s3api put-bucket-notification-configuration \
    --bucket source-bucket-name \
    --notification-configuration '{
        "LambdaFunctionConfigurations": [
        {
            "LambdaFunctionArn": "arn:aws:lambda:<region>:<account-id>:function:image-processing-lambda",
            "Events": ["s3:ObjectCreated:*"]
        }
        ]
    }'

# Grant S3 Permissions to Lambda Role

aws lambda add-permission \
  --function-name image-processing-lambda \
  --principal s3.amazonaws.com \
  --statement-id <unique-statement-id> \
  --action "lambda:InvokeFunction" \
  --source-arn arn:aws:s3:::source-bucket-name \
  --source-account <account-id>

# Test the Lambda Trigger

aws s3 cp path/to/your/image.jpg s3://source-bucket-name/

# Logs and Debugging
aws logs tail /aws/lambda/image-processing-lambda --follow