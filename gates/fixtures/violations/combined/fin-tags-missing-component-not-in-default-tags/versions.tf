# FIN-001 violation, file 1 of 2: default_tags carries Environment and
# ManagedBy - but NOT Component. The credit is tag-by-tag, not a blanket pass
# for any resource in a set that happens to declare a provider block.

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }
}
