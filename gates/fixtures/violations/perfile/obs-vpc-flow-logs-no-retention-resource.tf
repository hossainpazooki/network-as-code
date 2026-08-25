# OBS-002 violation: a bare aws_vpc resource with an aws_flow_log resource
# (so OBS-001 does not fire) but no aws_cloudwatch_log_group with a literal
# retention_in_days declared anywhere in this file.

resource "aws_vpc" "main" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Component = "networking"
  }
}

resource "aws_flow_log" "main" {
  vpc_id          = aws_vpc.main.id
  traffic_type    = "ALL"
  log_destination = aws_cloudwatch_log_group.flow_log.arn
}

resource "aws_cloudwatch_log_group" "flow_log" {
  name = "/aws/vpc/flow-log"
}
