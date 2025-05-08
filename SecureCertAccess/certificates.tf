# Certificate generation resources
resource "null_resource" "generate_certificates" {
  provisioner "local-exec" {
    command = <<-EOT
      # Create directory for certificates
      mkdir -p ~/certs
      cd ~/certs
      
      # Generate CA private key
      openssl genrsa -out ca.key 2048
      
      # Create self-signed CA certificate
      openssl req -new -x509 -sha256 -key ca.key -out ca.crt -days 365 \
        -subj "/CN=${var.project_name} CA/O=My Organization/C=US"
      
      # Generate workload private key
      openssl genrsa -out workload.key 2048
      
      # Create Certificate Signing Request (CSR)
      openssl req -new -key workload.key -out workload.csr \
        -subj "/CN=${var.project_name}-workload/O=My Organization/C=US"
      
      # Sign the CSR with our CA
      openssl x509 -req -in workload.csr -CA ca.crt -CAkey ca.key \
        -CAcreateserial -out workload.crt -days 365 -sha256
      
      # Verify the certificate
      openssl verify -CAfile ca.crt workload.crt
      
      # Set appropriate permissions
      chmod 600 ca.key workload.key
      chmod 644 ca.crt workload.crt
    EOT
  }
}

# Download the AWS Roles Anywhere credential helper
resource "null_resource" "install_credential_helper" {
  provisioner "local-exec" {
    command = <<-EOT
      # Download the credential helper
      curl -o aws_signing_helper https://s3.amazonaws.com/roles-anywhere-credential-helper/latest/aws_signing_helper-linux-amd64
      
      # Make it executable
      chmod +x aws_signing_helper
      
      # Move to a directory in PATH
      sudo mv aws_signing_helper /usr/local/bin/
    EOT
  }
}
