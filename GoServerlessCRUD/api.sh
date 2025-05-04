#!/bin/bash

set -e

# Configuration
AWS_REGION="us-east-1"
API_NAME="DynamoDB-CRUD-API"
LAMBDA_FUNCTION_NAME="dynamodb-crud-handler"
STAGE_NAME="prod"
API_DESCRIPTION="API for DynamoDB CRUD operations"

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

# Create REST API
echo "Creating API Gateway..."
API_ID=$(aws apigateway create-rest-api \
  --name "$API_NAME" \
  --description "$API_DESCRIPTION" \
  --region "$AWS_REGION" \
  --endpoint-configuration types=REGIONAL \
  | jq -r '.id')

echo "API created with ID: $API_ID"

# Get root resource ID
ROOT_RESOURCE_ID=$(aws apigateway get-resources \
  --rest-api-id "$API_ID" \
  --region "$AWS_REGION" \
  | jq -r '.items[0].id')

echo "Root resource ID: $ROOT_RESOURCE_ID"

# Create /items resource
ITEMS_RESOURCE_ID=$(aws apigateway create-resource \
  --rest-api-id "$API_ID" \
  --parent-id "$ROOT_RESOURCE_ID" \
  --path-part "items" \
  --region "$AWS_REGION" \
  | jq -r '.id')

echo "/items resource created with ID: $ITEMS_RESOURCE_ID"

# Create /items/{id} resource
ITEM_RESOURCE_ID=$(aws apigateway create-resource \
  --rest-api-id "$API_ID" \
  --parent-id "$ITEMS_RESOURCE_ID" \
  --path-part "{id}" \
  --region "$AWS_REGION" \
  | jq -r '.id')

echo "/items/{id} resource created with ID: $ITEM_RESOURCE_ID"

# Function to create API method
create_method() {
  local resource_id=$1
  local http_method=$2
  local lambda_arn=$3
  
  echo "Creating $http_method method on resource ID $resource_id..."
  
  aws apigateway put-method \
    --rest-api-id "$API_ID" \
    --resource-id "$resource_id" \
    --http-method "$http_method" \
    --authorization-type "NONE" \
    --region "$AWS_REGION"
  
  aws apigateway put-integration \
    --rest-api-id "$API_ID" \
    --resource-id "$resource_id" \
    --http-method "$http_method" \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri "arn:aws:apigateway:$AWS_REGION:lambda:path/2015-03-31/functions/$lambda_arn/invocations" \
    --region "$AWS_REGION"
  
  echo "$http_method method created successfully"
}

# Get Lambda function ARN
LAMBDA_ARN=$(aws lambda get-function \
  --function-name "$LAMBDA_FUNCTION_NAME" \
  --region "$AWS_REGION" \
  | jq -r '.Configuration.FunctionArn')

echo "Lambda ARN: $LAMBDA_ARN"

# Create methods for each CRUD operation
create_method "$ITEMS_RESOURCE_ID" "GET" "$LAMBDA_ARN"      # List items
create_method "$ITEMS_RESOURCE_ID" "POST" "$LAMBDA_ARN"     # Create item
create_method "$ITEM_RESOURCE_ID" "GET" "$LAMBDA_ARN"       # Get item
create_method "$ITEM_RESOURCE_ID" "PUT" "$LAMBDA_ARN"       # Update item
create_method "$ITEM_RESOURCE_ID" "DELETE" "$LAMBDA_ARN"    # Delete item

# Enable CORS
enable_cors() {
  local resource_id=$1
  local allowed_methods=$2

  echo "Enabling CORS on resource ID $resource_id with methods: $allowed_methods"

  aws apigateway put-method \
    --rest-api-id "$API_ID" \
    --resource-id "$resource_id" \
    --http-method OPTIONS \
    --authorization-type "NONE" \
    --region "$AWS_REGION"

  aws apigateway put-integration \
    --rest-api-id "$API_ID" \
    --resource-id "$resource_id" \
    --http-method OPTIONS \
    --type MOCK \
    --request-templates '{"application/json":"{\"statusCode\":200}"}' \
    --region "$AWS_REGION"

  aws apigateway put-method-response \
    --rest-api-id "$API_ID" \
    --resource-id "$resource_id" \
    --http-method OPTIONS \
    --status-code 200 \
    --response-parameters "method.response.header.Access-Control-Allow-Headers=true,method.response.header.Access-Control-Allow-Methods=true,method.response.header.Access-Control-Allow-Origin=true" \
    --region "$AWS_REGION"

  aws apigateway put-integration-response \
    --rest-api-id "$API_ID" \
    --resource-id "$resource_id" \
    --http-method OPTIONS \
    --status-code 200 \
    --response-parameters "method.response.header.Access-Control-Allow-Headers=\"'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'\",method.response.header.Access-Control-Allow-Methods=\"'$allowed_methods'\",method.response.header.Access-Control-Allow-Origin=\"'*'\"" \
    --region "$AWS_REGION"
}

# Apply CORS to both /items and /items/{id}
enable_cors "$ITEMS_RESOURCE_ID" "GET,POST,OPTIONS"
enable_cors "$ITEM_RESOURCE_ID" "GET,PUT,DELETE,OPTIONS"

# Deploy the API
echo "Deploying API to stage $STAGE_NAME..."
aws apigateway create-deployment \
  --rest-api-id "$API_ID" \
  --stage-name "$STAGE_NAME" \
  --region "$AWS_REGION"

# Add permissions for API Gateway to invoke Lambda
echo "Adding permissions for API Gateway to invoke Lambda..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws lambda add-permission \
  --function-name "$LAMBDA_FUNCTION_NAME" \
  --statement-id "apigateway-${API_ID}-items" \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:$AWS_REGION:$ACCOUNT_ID:$API_ID/*/*/items" \
  --region "$AWS_REGION" || true

aws lambda add-permission \
  --function-name "$LAMBDA_FUNCTION_NAME" \
  --statement-id "apigateway-${API_ID}-items-id" \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:$AWS_REGION:$ACCOUNT_ID:$API_ID/*/*/items/*" \
  --region "$AWS_REGION" || true

# Get the API URL
API_URL="https://${API_ID}.execute-api.${AWS_REGION}.amazonaws.com/${STAGE_NAME}"

echo ""
echo "✅ API Gateway setup complete!"
echo "🌐 API URL: $API_URL"
echo ""
echo "📣 Available Endpoints:"
echo "GET    $API_URL/items       - List all items"
echo "POST   $API_URL/items       - Create new item"
echo "GET    $API_URL/items/{id}  - Get specific item"
echo "PUT    $API_URL/items/{id}  - Update item"
echo "DELETE $API_URL/items/{id}  - Delete item"
