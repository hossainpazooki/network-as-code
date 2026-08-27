output "role_arn" {
  description = "ARN of the provisioner IAM role"
  value       = aws_iam_role.provisioner.arn
}

output "role_name" {
  description = "Name of the provisioner IAM role"
  value       = aws_iam_role.provisioner.name
}
