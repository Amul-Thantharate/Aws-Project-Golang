output "transfer_server_endpoint" {
	value = aws_transfer_server.transfer_server.endpoint
}

output "transfer_server_id" {
	value = aws_transfer_server.transfer_server.id
}

output "s3_bucket_arn" {
	value = aws_s3_bucket.transfer_bucket.arn
}

output "transfer_user" {
	value = aws_transfer_user.transfer_user.user_name
}
