package main

import (
	"context"
	"fmt"
	"image"
	"log"
	"os"
	"path"
	"path/filepath"
	"strings"
	"sync"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/disintegration/imaging"
)

var (
	s3Client          *s3.Client
	sourceBucket      = os.Getenv("SOURCE_BUCKET")
	destinationBucket = os.Getenv("DEST_BUCKET")
)

func init() {
	if sourceBucket == "" || destinationBucket == "" {
		log.Fatal("SOURCE_BUCKET or DEST_BUCKET environment variables not set")
	}
	cfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		log.Fatal("failed to load AWS SDK config: " + err.Error())
	}
	s3Client = s3.NewFromConfig(cfg)
}

// Download the image from the source S3 bucket
func downloadImage(bucket, key, localPath string) error {
	resp, err := s3Client.GetObject(context.TODO(), &s3.GetObjectInput{
		Bucket: aws.String(bucket),
		Key:    aws.String(key),
	})
	if err != nil {
		return fmt.Errorf("failed to get object from S3: %v", err)
	}
	defer resp.Body.Close()

	file, err := os.Create(localPath)
	if err != nil {
		return fmt.Errorf("failed to create local file: %v", err)
	}
	defer file.Close()

	_, err = file.ReadFrom(resp.Body)
	if err != nil {
		return fmt.Errorf("failed to write to local file: %v", err)
	}

	return nil
}

// Upload the processed image to the destination bucket
func uploadToS3(bucket, key, filePath string) error {
	file, err := os.Open(filePath)
	if err != nil {
		return fmt.Errorf("failed to open file: %v", err)
	}
	defer file.Close()

	_, err = s3Client.PutObject(context.TODO(), &s3.PutObjectInput{
		Bucket: aws.String(bucket),
		Key:    aws.String(key),
		Body:   file,
	})
	if err != nil {
		return fmt.Errorf("failed to upload file to S3: %v", err)
	}
	return nil
}

// Save image and upload to S3
func saveAndUpload(img image.Image, outputPath, s3Key string) error {
	if err := imaging.Save(img, outputPath); err != nil {
		return fmt.Errorf("failed to save image: %v", err)
	}
	defer os.Remove(outputPath)

	if err := uploadToS3(destinationBucket, s3Key, outputPath); err != nil {
		return fmt.Errorf("failed to upload image to S3: %v", err)
	}
	return nil
}

// Pixelate image using down-up scaling
func pixelateImage(inputPath, outputPath string, blockSizeX, blockSizeY int) error {
	img, err := imaging.Open(inputPath)
	if err != nil {
		return fmt.Errorf("failed to open image: %v", err)
	}

	w, h := img.Bounds().Dx(), img.Bounds().Dy()
	small := imaging.Resize(img, w/blockSizeX, h/blockSizeY, imaging.NearestNeighbor)
	pixelated := imaging.Resize(small, w, h, imaging.NearestNeighbor)

	return imaging.Save(pixelated, outputPath)
}

// Lambda handler
func handler(ctx context.Context, event events.S3Event) error {
	for _, record := range event.Records {
		imageKey := record.S3.Object.Key
		fmt.Printf("Processing file: %s\n", imageKey)

		ext := strings.ToLower(filepath.Ext(imageKey))
		baseName := strings.TrimSuffix(filepath.Base(imageKey), ext)
		localPath := "/tmp/original" + ext

		// Download image
		if err := downloadImage(sourceBucket, imageKey, localPath); err != nil {
			log.Printf("Error downloading image: %v", err)
			continue
		}
		defer os.Remove(localPath)

		img, err := imaging.Open(localPath)
		if err != nil {
			log.Printf("Error opening image: %v", err)
			continue
		}

		var wg sync.WaitGroup

		// Blur + Upscale goroutine
		wg.Add(1)
		go func() {
			defer wg.Done()

			// Blur
			blurred := imaging.Blur(img, 5.0)
			blurPath := fmt.Sprintf("/tmp/%s_blurred%s", baseName, ext)
			s3Key := path.Join("processed", fmt.Sprintf("%s_blurred%s", baseName, ext))
			if err := saveAndUpload(blurred, blurPath, s3Key); err != nil {
				log.Printf("Error uploading blurred image: %v", err)
			}

			// Upscale 2x and 4x
			w, h := img.Bounds().Dx(), img.Bounds().Dy()
			for _, scale := range []int{2, 4} {
				upscaled := imaging.Resize(img, w*scale, h*scale, imaging.Lanczos)
				upPath := fmt.Sprintf("/tmp/%s_upscale_%dx%s", baseName, scale, ext)
				upKey := path.Join("processed", fmt.Sprintf("%s_upscale_%dx%s", baseName, scale, ext))
				if err := saveAndUpload(upscaled, upPath, upKey); err != nil {
					log.Printf("Error uploading upscale %dx image: %v", scale, err)
				}
			}
		}()

		// Pixelation goroutine
		wg.Add(1)
		go func() {
			defer wg.Done()
			for _, size := range []int{8, 16, 32, 48, 64} {
				pixelPath := fmt.Sprintf("/tmp/%s_pixelated-%dx%d%s", baseName, size, size, ext)
				if err := pixelateImage(localPath, pixelPath, size, size); err != nil {
					log.Printf("Error pixelating image (%dx): %v", size, err)
					continue
				}

				s3Key := path.Join("processed", fmt.Sprintf("%s_pixelated-%dx%d%s", baseName, size, size, ext))
				if err := uploadToS3(destinationBucket, s3Key, pixelPath); err != nil {
					log.Printf("Error uploading pixelated image to S3: %v", err)
				} else {
					log.Printf("Uploaded pixelated image: %s", s3Key)
				}
				_ = os.Remove(pixelPath)
			}
		}()

		wg.Wait()
	}

	return nil
}

func main() {
	lambda.Start(handler)
}
