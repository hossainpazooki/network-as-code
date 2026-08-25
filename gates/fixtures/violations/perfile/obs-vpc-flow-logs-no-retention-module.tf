# OBS-002 violation: AWS VPC module enables flow logs but declares no
# retention period — neither flow_log_cloudwatch_log_group_retention_in_days
# on the module, nor an aws_cloudwatch_log_group with retention_in_days
# anywhere in this file. Must produce exactly ONE finding (OBS-002 only),
# never OBS-001 too.

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "sample-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  enable_flow_log    = true

  tags = {
    Component = "networking"
  }
}
