package main

import (
	"context"
	"encoding/json"
	"log"
	"os"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
)

// Item represents the data model
type Item struct {
	ID          string  `json:"id" dynamodbav:"id"`
	Name        string  `json:"name" dynamodbav:"name"`
	Description string  `json:"description" dynamodbav:"description"`
	Price       float64 `json:"price" dynamodbav:"price"`
}

var (
	dynamoClient *dynamodb.Client
	tableName    string
)

func init() {
	cfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		log.Fatalf("failed to load AWS config: %v", err)
	}
	dynamoClient = dynamodb.NewFromConfig(cfg)

	// Use environment variable in production
	tableName = os.Getenv("TABLE_NAME")
	if tableName == "" {
		tableName = "Items"
	}
}

func handler(ctx context.Context, request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	switch request.HTTPMethod {
	case "GET":
		if _, ok := request.PathParameters["id"]; ok {
			return GetItem(ctx, request)
		}
		return ListItems(ctx, request)
	case "POST":
		return CreateItem(ctx, request)
	case "PUT":
		return UpdateItem(ctx, request)
	case "DELETE":
		return DeleteItem(ctx, request)
	default:
		return events.APIGatewayProxyResponse{
			StatusCode: 405,
			Body:       `{"error": "Method not allowed"}`,
		}, nil
	}
}

func CreateItem(ctx context.Context, request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	var item Item
	if err := json.Unmarshal([]byte(request.Body), &item); err != nil {
		return Response(400, map[string]string{"error": "Invalid request body"}), nil
	}

	av, err := attributevalue.MarshalMap(item)
	if err != nil {
		log.Printf("Failed to marshal item: %v", err)
		return Response(500, map[string]string{"error": "Internal server error"}), nil
	}

	_, err = dynamoClient.PutItem(ctx, &dynamodb.PutItemInput{
		TableName: aws.String(tableName),
		Item:      av,
	})
	if err != nil {
		log.Printf("DynamoDB PutItem error: %v", err)
		return Response(500, map[string]string{"error": "Failed to create item"}), nil
	}

	return Response(201, item), nil
}

func GetItem(ctx context.Context, request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	id := request.PathParameters["id"]
	if id == "" {
		return Response(400, map[string]string{"error": "ID is required"}), nil
	}

	result, err := dynamoClient.GetItem(ctx, &dynamodb.GetItemInput{
		TableName: aws.String(tableName),
		Key: map[string]types.AttributeValue{
			"id": &types.AttributeValueMemberS{Value: id},
		},
	})
	if err != nil {
		log.Printf("DynamoDB GetItem error: %v", err)
		return Response(500, map[string]string{"error": "Failed to get item"}), nil
	}

	if result.Item == nil {
		return Response(404, map[string]string{"error": "Item not found"}), nil
	}

	var item Item
	if err := attributevalue.UnmarshalMap(result.Item, &item); err != nil {
		log.Printf("Unmarshal error: %v", err)
		return Response(500, map[string]string{"error": "Failed to process item"}), nil
	}

	return Response(200, item), nil
}

func ListItems(ctx context.Context, _ events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	result, err := dynamoClient.Scan(ctx, &dynamodb.ScanInput{
		TableName: aws.String(tableName),
	})
	if err != nil {
		log.Printf("DynamoDB Scan error: %v", err)
		return Response(500, map[string]string{"error": "Failed to list items"}), nil
	}

	var items []Item
	if err := attributevalue.UnmarshalListOfMaps(result.Items, &items); err != nil {
		log.Printf("Unmarshal error: %v", err)
		return Response(500, map[string]string{"error": "Failed to process items"}), nil
	}

	return Response(200, items), nil
}

func UpdateItem(ctx context.Context, request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	var item Item
	if err := json.Unmarshal([]byte(request.Body), &item); err != nil {
		return Response(400, map[string]string{"error": "Invalid request body"}), nil
	}

	// Verify item exists
	_, err := dynamoClient.GetItem(ctx, &dynamodb.GetItemInput{
		TableName: aws.String(tableName),
		Key: map[string]types.AttributeValue{
			"id": &types.AttributeValueMemberS{Value: item.ID},
		},
	})
	if err != nil {
		log.Printf("DynamoDB GetItem error: %v", err)
		return Response(500, map[string]string{"error": "Failed to verify item"}), nil
	}

	av, err := attributevalue.MarshalMap(item)
	if err != nil {
		log.Printf("Marshal error: %v", err)
		return Response(500, map[string]string{"error": "Internal server error"}), nil
	}

	_, err = dynamoClient.PutItem(ctx, &dynamodb.PutItemInput{
		TableName: aws.String(tableName),
		Item:      av,
	})
	if err != nil {
		log.Printf("DynamoDB PutItem error: %v", err)
		return Response(500, map[string]string{"error": "Failed to update item"}), nil
	}

	return Response(200, item), nil
}

func DeleteItem(ctx context.Context, request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	id := request.PathParameters["id"]
	if id == "" {
		return Response(400, map[string]string{"error": "ID is required"}), nil
	}

	_, err := dynamoClient.DeleteItem(ctx, &dynamodb.DeleteItemInput{
		TableName: aws.String(tableName),
		Key: map[string]types.AttributeValue{
			"id": &types.AttributeValueMemberS{Value: id},
		},
	})
	if err != nil {
		log.Printf("DynamoDB DeleteItem error: %v", err)
		return Response(500, map[string]string{"error": "Failed to delete item"}), nil
	}

	return Response(200, map[string]string{"message": "Item deleted successfully"}), nil
}

func Response(statusCode int, body interface{}) events.APIGatewayProxyResponse {
	jsonBody, _ := json.Marshal(body)
	return events.APIGatewayProxyResponse{
		StatusCode: statusCode,
		Body:       string(jsonBody),
		Headers:    map[string]string{"Content-Type": "application/json"},
	}
}

func main() {
	lambda.Start(handler)
}
