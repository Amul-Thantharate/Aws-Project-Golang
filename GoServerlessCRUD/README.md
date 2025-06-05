# Go Serverless CRUD API 🚀

A serverless CRUD API built with Go, AWS Lambda, and DynamoDB.

## Prerequisites 📋

- AWS CLI configured with appropriate credentials
- Go 1.20 or higher
- AWS Account with necessary permissions

## Setup Instructions 🛠️

### 1. Clone the Repository 📦
```bash
git clone <repository-url>
cd GoServerlessCRUD
```

### 2. Install Dependencies 📚
```bash
go mod tidy
```

### 3. Build the Lambda Function 🏗️
```bash
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o bootstrap ./...
```

### 4. Create Lambda Function 🚀
```bash
aws lambda create-function \
    --function-name dynamodb-crud-handler \
    --runtime provided.al2 \
    --role arn:aws:iam::<your-account-id>:role/lambda-dynamodb-execution-role \
    --handler bootstrap \
    --zip-file fileb://function.zip \
    --region us-east-1 \
    --environment 'Variables={TABLE_NAME=Items}'
```

### 5. Create DynamoDB Table 📊
```bash
aws dynamodb create-table \
    --table-name Items \
    --attribute-definitions AttributeName=id,AttributeType=S \
    --key-schema AttributeName=id,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region us-east-1
```

## API Endpoints 🌐

### 1. Create Item (POST /)
```bash
curl -X POST \
  https://<api-id>.execute-api.us-east-1.amazonaws.com/ \
  -H 'Content-Type: application/json' \
  -d ' {
    "id": "item1",
    "name": "Test Item",
    "description": "This is a test item",
    "price": 99.99
  }'
```

### 2. Get Item (GET /{id})
```bash
curl -X GET \
  https://<api-id>.execute-api.us-east-1.amazonaws.com/{id}
```

### 3. List Items (GET /)
```bash
curl -X GET \
  https://<api-id>.execute-api.us-east-1.amazonaws.com/
```

### 4. Update Item (PUT /)
```bash
curl -X PUT \
  https://<api-id>.execute-api.us-east-1.amazonaws.com/ \
  -H 'Content-Type: application/json' \
  -d ' {
    "id": "item1",
    "name": "Updated Item",
    "description": "This item has been updated",
    "price": 199.99
  }'
```

### 5. Delete Item (DELETE /{id})
```bash
curl -X DELETE \
  https://<api-id>.execute-api.us-east-1.amazonaws.com/{id}
```

## Cleanup 🧹

To clean up all resources:

1. Delete the Lambda function:
```bash
aws lambda delete-function --function-name dynamodb-crud-handler
```

2. Delete the DynamoDB table:
```bash
aws dynamodb delete-table --table-name Items
```

3. Delete the API Gateway (if created):
```bash
aws apigateway delete-rest-api --rest-api-id <api-id>
```

## Security Considerations 🔒

- Ensure your Lambda function has the necessary IAM permissions
- Consider implementing API Key authentication for production
- Enable CORS if needed
- Implement request validation

## Contributing 🤝

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a new Pull Request

## License 📄

This project is licensed under the MIT License - see the LICENSE file for details.