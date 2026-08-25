# Conforming: AWS VPC module with flow logs enabled AND an explicit
# retention period declared on the module. Neither OBS-001 nor OBS-002
# should fire.

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "sample-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true

  enable_flow_log                                 = true
  flow_log_cloudwatch_log_group_retention_in_days = 30

  tags = {
    Component = "networking"
  }
}
