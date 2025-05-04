#!/bin/bash

# Configuration
PROJECT_NAME="dynamodb-crud-api"
AWS_REGION="us-east-1"
DYNAMODB_TABLE="Items"
LAMBDA_ROLE_NAME="$PROJECT_NAME-lambda-role"
LAMBDA_FUNCTION_NAME="$PROJECT_NAME-handler"

# Exit on error
set -e

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "jq is not installed. Please install it first."
    exit 1
fi

# Check if DynamoDB table exists
echo "Checking if DynamoDB table exists..."
if aws dynamodb describe-table --table-name $DYNAMODB_TABLE --region $AWS_REGION &> /dev/null; then
    echo "DynamoDB table $DYNAMODB_TABLE already exists. Skipping creation."
else
    echo "Creating DynamoDB table..."
    aws dynamodb create-table \
        --table-name $DYNAMODB_TABLE \
        --attribute-definitions AttributeName=id,AttributeType=S \
        --key-schema AttributeName=id,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region $AWS_REGION

    echo "Waiting for table to be created..."
    aws dynamodb wait table-exists \
        --table-name $DYNAMODB_TABLE \
        --region $AWS_REGION
fi

# Check if IAM role exists
echo "Checking if IAM role exists..."
ROLE_ARN=$(aws iam get-role --role-name $LAMBDA_ROLE_NAME --region $AWS_REGION 2>/dev/null | jq -r '.Role.Arn')
if [ "$ROLE_ARN" != "null" ]; then
    echo "IAM role $LAMBDA_ROLE_NAME already exists. Skipping creation."
else
    echo "Creating IAM role for Lambda..."
    ROLE_ARN=$(aws iam create-role \
        --role-name $LAMBDA_ROLE_NAME \
        --assume-role-policy-document '{
            "Version": "2012-10-17",
            "Statement": [{
                "Effect": "Allow",
                "Principal": {
                    "Service": "lambda.amazonaws.com"
                },
                "Action": "sts:AssumeRole"
            }]
        }' \
        --region $AWS_REGION | jq -r '.Role.Arn')

    # Attach policies to the role
    echo "Attaching policies to the role..."
    aws iam attach-role-policy \
        --role-name $LAMBDA_ROLE_NAME \
        --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess \
        --region $AWS_REGION

    aws iam attach-role-policy \
        --role-name $LAMBDA_ROLE_NAME \
        --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole \
        --region $AWS_REGION

    echo "Waiting for IAM role to be ready..."
    sleep 10
fi

# Check if Lambda function exists
echo "Checking if Lambda function exists..."
LAMBDA_ARN=$(aws lambda get-function --function-name $LAMBDA_FUNCTION_NAME --region $AWS_REGION 2>/dev/null | jq -r '.Configuration.FunctionArn')
if [ "$LAMBDA_ARN" != "null" ]; then
    echo "Lambda function $LAMBDA_FUNCTION_NAME already exists. Skipping creation."
else
    # Build and package the Lambda function
    echo "Building the Go Lambda function..."
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o bootstrap main.go
    zip function.zip bootstrap

    # Create Lambda function
    echo "Creating Lambda function..."
    LAMBDA_ARN=$(aws lambda create-function \
        --function-name $LAMBDA_FUNCTION_NAME \
        --runtime provided.al2 \
        --handler main \
        --zip-file fileb://function.zip \
        --role $ROLE_ARN \
        --region $AWS_REGION | jq -r '.FunctionArn')

    echo "Waiting for Lambda function to be ready..."
    aws lambda wait function-active \
        --function-name $LAMBDA_FUNCTION_NAME \
        --region $AWS_REGION
fi
