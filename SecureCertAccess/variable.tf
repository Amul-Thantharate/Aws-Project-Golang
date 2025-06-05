variable "project_name" {
    description = "Name of the project"
    default     = "SecureCertAccess"
}

variable "ca_cert_path" {
    description = "Path to the CA certificate file"
    default     = "~/certs/ca.crt"
}