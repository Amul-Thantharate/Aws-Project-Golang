#!/bin/bash

PROJECT_NAME="dynamodb-crud-api"
AWS_REGION="us-east-1"
DYNAMODB_TABLE="Items"
LAMBDA_ROLE_NAME="$PROJECT_NAME-lambda-role"
LAMBDA_FUNCTION_NAME="$PROJECT_NAME-handler"
API_GATEWAY_NAME="$PROJECT_NAME-api"
STAGE_NAME="dev"

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

# Get API Gateway ID
echo "Getting API Gateway ID..."
API_ID=$(aws apigateway get-rest-apis \
    --query "items[?name=='$API_GATEWAY_NAME'].id" \
    --output text \
    --region $AWS_REGION)

# Delete API Gateway if exists
if [ -n "$API_ID" ]; then
    echo "Deleting API Gateway..."
    aws apigateway delete-rest-api \
        --rest-api-id $API_ID \
        --region $AWS_REGION
else
    echo "API Gateway not found, skipping deletion"
fi

# Delete Lambda function if exists
echo "Checking for Lambda function..."
if aws lambda get-function \
    --function-name $LAMBDA_FUNCTION_NAME \
    --region $AWS_REGION &> /dev/null; then
    echo "Deleting Lambda function..."
    aws lambda delete-function \
        --function-name $LAMBDA_FUNCTION_NAME \
        --region $AWS_REGION
else
    echo "Lambda function not found, skipping deletion"
fi

# Detach policies and delete IAM role
echo "Checking for IAM role..."
if aws iam get-role \
    --role-name $LAMBDA_ROLE_NAME \
    &> /dev/null; then
    
    echo "Detaching policies from role..."
    # List all attached policies
    POLICIES=$(aws iam list-attached-role-policies \
        --role-name $LAMBDA_ROLE_NAME \
        --query "AttachedPolicies[].PolicyArn" \
        --output text)
    
    # Detach each policy
    for POLICY_ARN in $POLICIES; do
        aws iam detach-role-policy \
            --role-name $LAMBDA_ROLE_NAME \
            --policy-arn $POLICY_ARN
    done
    
    echo "Deleting IAM role..."
    aws iam delete-role \
        --role-name $LAMBDA_ROLE_NAME
else
    echo "IAM role not found, skipping deletion"
fi

# Delete DynamoDB table if exists
echo "Checking for DynamoDB table..."
if aws dynamodb describe-table \
    --table-name $DYNAMODB_TABLE \
    --region $AWS_REGION &> /dev/null; then
    echo "Deleting DynamoDB table..."
    aws dynamodb delete-table \
        --table-name $DYNAMODB_TABLE \
        --region $AWS_REGION
    
    echo "Waiting for table to be deleted..."
    aws dynamodb wait table-not-exists \
        --table-name $DYNAMODB_TABLE \
        --region $AWS_REGION
else
    echo "DynamoDB table not found, skipping deletion"
fi

# Clean up local files
echo "Cleaning up local files..."
rm -f main function.zip

echo "Teardown complete! All resources have been deleted."