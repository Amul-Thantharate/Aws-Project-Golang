# 🌈 PixlFlow

A powerful Go-based image transformation utility with AWS Lambda integration

## 📋 Overview

PixlFlow is a Go application that processes images with various transformations including blurring, upscaling, and pixelation effects. It can run locally or be deployed as an AWS Lambda function triggered by S3 uploads.

## ✨ Features

- 🖼️ **Bulk Image Processing**: Process all images from an input directory
- 🌫️ **Blur Effect**: Apply customizable blur to images
- 🔍 **Upscaling**: Enlarge images by 2x and 4x using Lanczos algorithm
- 🎮 **Pixelation**: Create pixel art effects at various resolutions (8x8 to 64x64)
- ☁️ **AWS Lambda Ready**: Deploy as serverless function with S3 triggers

## 🚀 Getting Started

### Prerequisites

- Go 1.24.1 or later
- AWS CLI (for Lambda deployment)
- AWS account (for Lambda deployment)

### 🔧 Installation

1. Clone the repository:
   ```
   git clone <repository-url>
   cd PixlFlow
   ```

2. Install dependencies:
   ```
   go mod download
   ```

## 🏃‍♂️ Local Usage

1. Create input and output directories:
   ```
   mkdir -p input output
   ```

2. Place your images in the `input` directory

3. Run the application:
   ```
   go run main.go
   ```

4. Find processed images in the `output` directory

## 📁 Directory Structure

- `input/` - Place original images here
- `output/` - Processed images will be saved here
- `main.go` - Main application code
- `bash.sh` - AWS deployment script
- `policy.json` - AWS IAM policy for Lambda function

## 🌩️ AWS Lambda Deployment

1. Update the bash.sh script with your specific AWS account details:
   - Replace `<account-id>` with your AWS account ID
   - Replace `<region>` with your AWS region
   - Replace `source-bucket-name` and `destination-bucket-name` with your S3 bucket names
   - Replace `<unique-statement-id>` with a unique identifier
   - Replace `<Bucket-name> in the provider block` with your S3 bucket name

2. Run the deployment script:
   ```
   terraform init
   terraform apply
   ```

3. Upload images to your source S3 bucket to trigger processing

## 🛠️ Image Transformations

### Blur Effect
Images are blurred with a 5.0 radius parameter

### Upscaling
Images are upscaled by factors of 2x and 4x using Lanczos algorithm

### Pixelation
Images are pixelated at 5 different resolutions:
- 8x8 pixels
- 16x16 pixels
- 32x32 pixels
- 48x48 pixels
- 64x64 pixels

## 📝 Example Output Files

For an input file named `example.jpg`, the following outputs will be generated:
- `example_blurred.jpg` - Blurred version
- `example_upscale_2x.jpg` - 2x upscaled version
- `example_upscale_4x.jpg` - 4x upscaled version
- `example_pixelated-8x8.jpg` - 8x8 pixelated version
- `example_pixelated-16x16.jpg` - 16x16 pixelated version
- `example_pixelated-32x32.jpg` - 32x32 pixelated version
- `example_pixelated-48x48.jpg` - 48x48 pixelated version
- `example_pixelated-64x64.jpg` - 64x64 pixelated version

## 📋 Dependencies

- [disintegration/imaging](https://github.com/disintegration/imaging) - Go image processing library

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

⭐ Made with ❤️ by Amul Thantharate
