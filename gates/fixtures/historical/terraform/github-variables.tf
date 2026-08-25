# -----------------------------------------------------------------------------
# GitHub (for OIDC IAM roles)
# -----------------------------------------------------------------------------

variable "github_org" {
  description = "GitHub organization name"
  type        = string
  default     = "hossa"
}

variable "api_repo_name" {
  description = "GitHub repository name for the API project"
  type        = string
  default     = "institutional-defi-platform-api"
}

variable "infra_repo_name" {
  description = "GitHub repository name for the infra project"
  type        = string
  default     = "institutional-defi-platform-infra"
}
