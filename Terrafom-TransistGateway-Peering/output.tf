output "east_ec2_public_ip" {
  value = aws_instance.east_ec2.public_ip
}

output "east_ec2_private_ip" {
  value = aws_instance.east_ec2.private_ip
}

output "west_ec2_public_ip" {
  value = aws_instance.west_ec2.public_ip
}

output "west_ec2_private_ip" {
  value = aws_instance.west_ec2.private_ip
}

