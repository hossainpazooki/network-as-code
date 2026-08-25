# OBS-001 violation: AWS VPC module with no flow logs enabled at all —
# no enable_flow_log argument, and no aws_flow_log resource anywhere in
# this file. Modeled directly on fixtures/historical/terraform/vpc.tf.

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "sample-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true

  tags = {
    Component = "networking"
  }
}
