# FIN-001 conforming, file 1 of 2. This file declares the provider and NO
# resources at all - exactly the layout of the vendored historical config
# (fixtures/historical/terraform/versions.tf). In Terraform, default_tags is a
# property of the PROVIDER CONFIGURATION: it applies to every resource in the
# root module regardless of which .tf file the resource is written in. A
# per-file rule cannot see this, which is why FIN-001 is a combined-mode rule.

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Environment = "dev"
      ManagedBy   = "terraform"
      Project     = "institutional-defi"
    }
  }
}
