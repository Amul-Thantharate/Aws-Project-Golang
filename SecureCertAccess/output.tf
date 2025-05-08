output "trust_anchor_arn" {
    value = aws_rolesanywhere_trust_anchor.ca_anchor.arn
}

output "profile_arn" {
    value = aws_rolesanywhere_profile.workload_profile.arn
}

output "role_arn" {
    value = aws_iam_role.roles_anywhere_role.arn
}

output "credential_helper_command" {
    value = <<-EOT
        aws_signing_helper credential-process \
        --certificate ~/certs/workload.crt \
        --private-key ~/certs/workload.key \
        --trust-anchor-arn ${aws_rolesanywhere_trust_anchor.ca_anchor.arn} \
        --profile-arn ${aws_rolesanywhere_profile.workload_profile.arn} \
        --role-arn ${aws_iam_role.roles_anywhere_role.arn}
    EOT
}

output "aws_config_profile" {
    value = <<-EOT
        [profile ${var.project_name}]
        credential_process = aws_signing_helper credential-process --certificate ~/certs/workload.crt --private-key ~/certs/workload.key --trust-anchor-arn ${aws_rolesanywhere_trust_anchor.ca_anchor.arn} --profile-arn ${aws_rolesanywhere_profile.workload_profile.arn} --role-arn ${aws_iam_role.roles_anywhere_role.arn}
    EOT
}
