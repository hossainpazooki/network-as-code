# -----------------------------------------------------------------------------
# IAM Role ARNs (CI/CD)
# -----------------------------------------------------------------------------

output "builder_role_arn" {
  description = "IAM role ARN for GitHub Actions builder (ECR push)"
  value       = module.builder_role.role_arn
}

output "provisioner_role_arn" {
  description = "IAM role ARN for GitHub Actions provisioner (Terraform + kubectl)"
  value       = module.provisioner_role.role_arn
}
