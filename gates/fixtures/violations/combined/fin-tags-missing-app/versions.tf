# FIN-001 violation, file 1 of 2: provider-wide default_tags supplying
# Environment. Present so the refusal below cannot be explained away as the
# rule simply failing to see default_tags.

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }
}
