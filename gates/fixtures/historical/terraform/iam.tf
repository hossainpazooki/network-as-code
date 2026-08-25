# -----------------------------------------------------------------------------
# IAM Modules
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

# GitHub Actions role for building and pushing Docker images
module "builder_role" {
  source = "../modules/iam/builder"

  project_name  = var.project_name
  github_org    = var.github_org
  api_repo_name = var.api_repo_name
  ecr_repository_arns = [
    aws_ecr_repository.regulatory_workbench.arn,
  ]
}

# GitHub Actions role for infrastructure provisioning and deployment
module "provisioner_role" {
  source = "../modules/iam/provisioner"

  project_name    = var.project_name
  github_org      = var.github_org
  infra_repo_name = var.infra_repo_name
  aws_region      = var.aws_region
  aws_account_id  = data.aws_caller_identity.current.account_id
  ecr_repository_arns = [
    aws_ecr_repository.regulatory_workbench.arn,
  ]
}

# Pod-level IRSA roles (ALB controller, ESO, application SA)
module "pod_roles" {
  source = "../modules/iam/pod"

  project_name      = var.project_name
  aws_region        = var.aws_region
  oidc_provider_arn = module.eks.oidc_provider_arn
}
