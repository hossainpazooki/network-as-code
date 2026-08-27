output "alb_controller_role_arn" {
  description = "IAM role ARN for ALB Ingress Controller"
  value       = module.alb_controller_irsa.iam_role_arn
}

output "eso_role_arn" {
  description = "IAM role ARN for External Secrets Operator"
  value       = module.eso_irsa.iam_role_arn
}

output "idpa_sa_role_arn" {
  description = "IAM role ARN for application service account (idpa-sa)"
  value       = module.idpa_sa_irsa.iam_role_arn
}
