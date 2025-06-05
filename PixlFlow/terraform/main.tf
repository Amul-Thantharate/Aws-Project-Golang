resource "aws_s3_bucket" "source_bucket" {
    bucket = "${var.project_name}-source-go"
}

resource "aws_s3_bucket" "dest_bucket" {
    bucket = "${var.project_name}-dest-go"
}

resource "aws_s3_bucket" "lambda_code_bucket" {
    bucket = "${var.project_name}-lambda-code"
}

resource "aws_s3_object" "lambda_zip" {
    bucket = aws_s3_bucket.lambda_code_bucket.id
    key    = "function.zip"
    source = "${path.module}/../function.zip"
    etag   = filemd5("${path.module}/../function.zip")
}

resource "aws_iam_role" "lambda_exec_role" {
    name = "${var.project_name}-lambda-role"
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
        Effect = "Allow"
        Principal = {
            Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        }]
    })
}

resource "aws_iam_policy" "lambda_policy" {
    name = "${var.project_name}-lambda-policy"
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Effect = "Allow"
            Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
            ]
            Resource = "arn:aws:logs:*:*:*"
        },
        {
            Effect = "Allow"
            Action = [
            "s3:GetObject",
            "s3:PutObject"
            ]
            Resource = [
            "${aws_s3_bucket.source_bucket.arn}/*",
            "${aws_s3_bucket.dest_bucket.arn}/*"
            ]
        }
        ]
    })
}

resource "aws_iam_role_policy_attachment" "lambda_attach_policy" {
    role       = aws_iam_role.lambda_exec_role.name
    policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_lambda_function" "image_processor" {
    function_name = "${var.project_name}-lambda"
    role          = aws_iam_role.lambda_exec_role.arn
    handler       = "bootstrap"
    runtime       = "provided.al2"

    s3_bucket = aws_s3_bucket.lambda_code_bucket.id
    s3_key    = aws_s3_object.lambda_zip.key

    environment {
        variables = {
        SOURCE_BUCKET = aws_s3_bucket.source_bucket.bucket
        DEST_BUCKET   = aws_s3_bucket.dest_bucket.bucket
        }
    }

    timeout = 30
}


resource "aws_s3_bucket_notification" "bucket_notification" {
    bucket = aws_s3_bucket.source_bucket.id

    lambda_function {
        lambda_function_arn = aws_lambda_function.image_processor.arn
        events              = ["s3:ObjectCreated:*"]
    }

    depends_on = [
        aws_lambda_permission.allow_s3_invocation
    ]
}

resource "aws_lambda_permission" "allow_s3_invocation" {
    statement_id  = "AllowExecutionFromS3"
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.image_processor.function_name
    principal     = "s3.amazonaws.com"
    source_arn    = aws_s3_bucket.source_bucket.arn
}
