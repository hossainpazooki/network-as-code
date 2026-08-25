# A CONFORMING fixture must conform to EVERY family, not just its own: all
# three rule families load into package main, so FIN-001's allocation tags
# (Component/Environment/App) are required here too.
# Sanity fixture: infrastructure that is not a VPC (module or resource) at
# all must never trigger OBS-001 / OBS-002.

resource "aws_ecr_repository" "app" {
  name                 = "sample-app"
  image_tag_mutability = "IMMUTABLE"

  tags = {
    Component   = "registry"
    Environment = "dev"
    App         = "sample-app"
  }
}
