package main

import (
	"context"
	"fmt"
	"log"
	"mime/multipart"
	"net/http"
	"path/filepath"
	"strings"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/gin-gonic/gin"
)

var (
	s3Client *s3.Client
	bucket   = "your-s3-bucket-name"
	region   = "us-east-1"
)

func initAWS() {
	cfg, err := config.LoadDefaultConfig(context.TODO(), config.WithRegion(region))
	if err != nil {
		log.Fatalf("Unable to load AWS config: %v", err)
	}
	s3Client = s3.NewFromConfig(cfg)
}

func uploadToS3(fileHeader *multipart.FileHeader) (string, error) {
	file, err := fileHeader.Open()
	if err != nil {
		return "", err
	}
	defer file.Close()

	key := filepath.Base(fileHeader.Filename)
	contentType := fileHeader.Header.Get("Content-Type")
	if !strings.HasPrefix(contentType, "image/") && !strings.HasPrefix(contentType, "application/") {
		return "", fmt.Errorf("unsupported file type: %s", contentType)
	}

	_, err = s3Client.PutObject(context.TODO(), &s3.PutObjectInput{
		Bucket:      aws.String(bucket),
		Key:         aws.String(key),
		Body:        file,
		ContentType: aws.String(contentType),
	})
	if err != nil {
		return "", err
	}

	url := fmt.Sprintf("https://%s.s3.%s.amazonaws.com/%s", bucket, region, key)
	return url, nil
}

func main() {
	initAWS()
	router := gin.Default()
	router.Static("/static", "./static")
	router.LoadHTMLFiles("static/index.html")

	router.GET("/", func(c *gin.Context) {
		c.HTML(http.StatusOK, "index.html", nil)
	})

	router.POST("/upload", func(c *gin.Context) {
		file, err := c.FormFile("file")
		if err != nil {
			log.Println("Error receiving file:", err)
			c.String(http.StatusBadRequest, "File not received: %v", err)
			return
		}

		url, err := uploadToS3(file)
		if err != nil {
			log.Println("Upload failed:", err)
			c.String(http.StatusInternalServerError, "Upload failed: %v", err)
			return
		}

		log.Printf("Uploaded: %s", url)
		c.String(http.StatusOK, url)
	})

	router.Run(":8080")
}
