# -----------------------------------------------------------------------------
# ECR Repositories
#
# The `api` and `worker` repositories were removed when
# institutional-defi-platform-api was decommissioned. The platform's remaining
# containerised workload is the regulatory-workbench frontend.
# -----------------------------------------------------------------------------

resource "aws_ecr_repository" "regulatory_workbench" {
  name                 = "${var.project_name}-regulatory-workbench"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Component = "registry"
  }
}

# Lifecycle policies — keep last 30 images

resource "aws_ecr_lifecycle_policy" "regulatory_workbench" {
  repository = aws_ecr_repository.regulatory_workbench.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 30 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 30
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
