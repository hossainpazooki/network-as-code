variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "github_org" {
  description = "GitHub organization name"
  type        = string
}

variable "api_repo_name" {
  description = "GitHub repository name for the API project"
  type        = string
}

variable "ecr_repository_arns" {
  description = "List of ECR repository ARNs the builder can push to"
  type        = list(string)
}
