package main

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-xray-sdk-go/xray"
)

var (
	s3Client   *s3.Client
	bucketName string
)

type DogAPIResponse struct {
	Message string `json:"message"`
	Status  string `json:"status"`
}

type LambdaResponse struct {
	StatusCode      int               `json:"statusCode"`
	Headers         map[string]string `json:"headers"`
	Body            string            `json:"body"`
	IsBase64Encoded bool              `json:"isBase64Encoded"`
}

func init() {
	cfg, err := config.LoadDefaultConfig(context.TODO(),
		config.WithClientLogMode(aws.LogSigning|aws.LogRetries|aws.LogRequest),
	)
	if err != nil {
		panic(fmt.Sprintf("failed to load AWS config: %v", err))
	}

	// Note: AWS SDK v2 does not yet support native X-Ray wrapping
	s3Client = s3.NewFromConfig(cfg)

	bucketName = os.Getenv("BUCKET_NAME")
	if bucketName == "" {
		panic("BUCKET_NAME environment variable is not set")
	}
}

func getDogImage(ctx context.Context) ([]byte, string, error) {
	client := xray.Client(&http.Client{})

	endpoint := "https://dog.ceo/api/breeds/image/random"
	req, err := http.NewRequestWithContext(ctx, "GET", endpoint, nil)
	if err != nil {
		return nil, "", fmt.Errorf("failed to create Dog API request: %w", err)
	}

	resp, err := client.Do(req)
	if err != nil {
		return nil, "", fmt.Errorf("failed to call Dog API: %w", err)
	}
	defer resp.Body.Close()

	var dogResponse DogAPIResponse
	if err := json.NewDecoder(resp.Body).Decode(&dogResponse); err != nil {
		return nil, "", fmt.Errorf("failed to decode Dog API response: %w", err)
	}

	imageURL := dogResponse.Message
	imageName := imageURL[strings.LastIndex(imageURL, "/")+1:]

	req, err = http.NewRequestWithContext(ctx, "GET", imageURL, nil)
	if err != nil {
		return nil, "", fmt.Errorf("failed to create image download request: %w", err)
	}

	imageResp, err := client.Do(req)
	if err != nil {
		return nil, "", fmt.Errorf("failed to download image: %w", err)
	}
	defer imageResp.Body.Close()

	imageData, err := io.ReadAll(imageResp.Body)
	if err != nil {
		return nil, "", fmt.Errorf("failed to read image data: %w", err)
	}

	return imageData, imageName, nil
}

func getContentTypeFromExt(name string) string {
	switch strings.ToLower(filepath.Ext(name)) {
	case ".jpg", ".jpeg":
		return "image/jpeg"
	case ".png":
		return "image/png"
	case ".gif":
		return "image/gif"
	default:
		return "application/octet-stream"
	}
}

func saveToS3(ctx context.Context, imageData []byte, imageName string) error {
	contentType := getContentTypeFromExt(imageName)

	_, err := s3Client.PutObject(ctx, &s3.PutObjectInput{
		Bucket:      aws.String(bucketName),
		Key:         aws.String(imageName),
		Body:        bytes.NewReader(imageData),
		ContentType: aws.String(contentType),
	})
	return err
}

func handler(ctx context.Context) (LambdaResponse, error) {
	ctx, seg := xray.BeginSegment(ctx, "handler")
	defer seg.Close(nil)

	var (
		imageData []byte
		imageName string
		err       error
	)

	err = xray.Capture(ctx, "get_dog_image", func(ctx context.Context) error {
		imageData, imageName, err = getDogImage(ctx)
		return err
	})
	if err != nil {
		return LambdaResponse{
			StatusCode: http.StatusInternalServerError,
			Body:       fmt.Sprintf("Error getting dog image: %v", err),
		}, nil
	}

	err = xray.Capture(ctx, "save_to_s3", func(ctx context.Context) error {
		return saveToS3(ctx, imageData, imageName)
	})
	if err != nil {
		return LambdaResponse{
			StatusCode: http.StatusInternalServerError,
			Body:       fmt.Sprintf("Error saving to S3: %v", err),
		}, nil
	}

	encodedImage := base64.StdEncoding.EncodeToString(imageData)
	contentType := getContentTypeFromExt(imageName)

	return LambdaResponse{
		StatusCode: http.StatusOK,
		Headers: map[string]string{
			"Content-Type": contentType,
		},
		Body:            encodedImage,
		IsBase64Encoded: true,
	}, nil
}

func main() {
	lambda.Start(handler)
}
