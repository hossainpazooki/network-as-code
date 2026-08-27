output "role_arn" {
  description = "ARN of the builder IAM role"
  value       = aws_iam_role.builder.arn
}

output "role_name" {
  description = "Name of the builder IAM role"
  value       = aws_iam_role.builder.name
}
