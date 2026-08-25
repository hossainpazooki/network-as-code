# -----------------------------------------------------------------------------
# Networking
# -----------------------------------------------------------------------------

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

# -----------------------------------------------------------------------------
# EKS
# -----------------------------------------------------------------------------

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_oidc_provider_arn" {
  description = "EKS OIDC provider ARN for IRSA"
  value       = module.eks.oidc_provider_arn
}

# -----------------------------------------------------------------------------
# ECR
# -----------------------------------------------------------------------------

output "ecr_regulatory_workbench_url" {
  description = "ECR repository URL for regulatory-workbench image"
  value       = aws_ecr_repository.regulatory_workbench.repository_url
}

# -----------------------------------------------------------------------------
# RDS
# -----------------------------------------------------------------------------

output "app_db_endpoint" {
  description = "Application database endpoint"
  value       = module.app_db.db_instance_endpoint
}

output "temporal_db_endpoint" {
  description = "Temporal database endpoint"
  value       = module.temporal_db.db_instance_endpoint
}

# -----------------------------------------------------------------------------
# ElastiCache
# -----------------------------------------------------------------------------

output "redis_endpoint" {
  description = "Redis primary endpoint"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

# -----------------------------------------------------------------------------
# IRSA Role ARNs (Pod-level)
# -----------------------------------------------------------------------------

output "alb_controller_role_arn" {
  description = "IAM role ARN for ALB Ingress Controller"
  value       = module.pod_roles.alb_controller_role_arn
}

output "eso_role_arn" {
  description = "IAM role ARN for External Secrets Operator"
  value       = module.pod_roles.eso_role_arn
}

output "idpa_sa_role_arn" {
  description = "IAM role ARN for application service account (idpa-sa)"
  value       = module.pod_roles.idpa_sa_role_arn
}
