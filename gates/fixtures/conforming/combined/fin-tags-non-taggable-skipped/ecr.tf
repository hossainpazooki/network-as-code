# FIN-001 conforming: aws_ecr_lifecycle_policy has no `tags` argument in the
# AWS provider schema at all (verified against the vendored
# fixtures/historical/terraform/ecr.tf, which never tagged this type). It must
# not be flagged merely for carrying no tags, and there is deliberately no
# provider block in this set to rescue it.

resource "aws_ecr_lifecycle_policy" "example" {
  repository = "institutional-defi-regulatory-workbench"

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
