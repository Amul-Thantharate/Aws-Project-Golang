# AWS Lambda X-Ray Event Handler 🐶

This project is an AWS Lambda function that demonstrates how to use AWS X-Ray for tracing and monitoring HTTP requests. The function fetches random dog images from the Dog API, saves them to an S3 bucket, and returns the image URL. 🚀

## Features ✨

- AWS Lambda function written in Go 🐙
- AWS X-Ray integration for request tracing 📊
- S3 integration for storing images 📁
- Error handling and logging 🛡️
- Environment variable configuration 🔧

## Prerequisites 📋

- AWS CLI configured with appropriate permissions 🔑
- Go 1.16 or later 🐱
- AWS account with Lambda and S3 permissions 🏦

## Setup 🛠️

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd lambda-xray-event
   ```

2. Install dependencies:
   ```bash
   go mod tidy
   ```

3. Create an S3 bucket for storing images 📁

4. Set up environment variables:
   - `BUCKET_NAME`: Name of your S3 bucket 🏷️

5. Build and package the function:
   ```bash
   go build -o bootstrap main.go
   zip function.zip bootstrap
   ```

6. Deploy to AWS Lambda:
   - Create a new Lambda function 🚀
   - Upload the `function.zip` file 💾
   - Set the handler to `bootstrap` 🛠️
   - Configure the environment variables 🔧
   - Set up the trust policy (using `trust-policy.json`) 🔐

## Functionality 🤖

The Lambda function performs the following steps:

1. Makes a request to the Dog API to get a random dog image URL 🐶
2. Downloads the image from the URL 📥
3. Saves the image to the specified S3 bucket 📁
4. Returns a response containing the S3 URL of the saved image 📤

## Monitoring 📊

The function uses AWS X-Ray for tracing HTTP requests to the Dog API. You can view the traces in the AWS X-Ray console to:

- Track request latency ⏱️
- View request/response details 📄
- Monitor error rates 🚨
- Analyze request patterns 📈

## Error Handling 🛡️

The function includes comprehensive error handling for:
- AWS configuration issues ⚠️
- HTTP request failures ❌
- S3 upload errors 📁
- Invalid environment variables 🔧

## Security 🔐

- All HTTP requests are made through AWS X-Ray's wrapped client for proper tracing 📊
- Environment variables are used for sensitive configuration 🔏
- Proper error handling prevents information leakage 🛡️

## License 📄

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing 🤝

1. Fork the repository 🍴
2. Create your feature branch 🌱
3. Commit your changes 📝
4. Push to the branch 🚀
5. Create a new Pull Request 📅

## Support 💬

For support, please open an issue in the repository or contact the maintainers.

## Acknowledgments 🙏

- Uses the Dog API (https://dog.ceo/dog-api/) 🐶
- Built with AWS SDK for Go v2 🐙
- Uses AWS X-Ray for tracing 📊