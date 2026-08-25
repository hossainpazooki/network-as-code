# A CONFORMING fixture must conform to EVERY family, not just its own: all
# three rule families load into package main, so FIN-001's allocation tags
# (Component/Environment/App) are required here too.
# Conforming: a bare aws_vpc resource with an aws_flow_log resource AND an
# aws_cloudwatch_log_group declaring a literal retention_in_days. Neither
# OBS-001 nor OBS-002 should fire.

resource "aws_vpc" "main" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Component   = "networking"
    Environment = "dev"
    App         = "sample-app"
  }
}

resource "aws_cloudwatch_log_group" "flow_log" {
  name              = "/aws/vpc/flow-log"
  retention_in_days = 90

  tags = {
    Component   = "networking"
    Environment = "dev"
    App         = "sample-app"
  }
}

resource "aws_flow_log" "main" {
  vpc_id          = aws_vpc.main.id
  traffic_type    = "ALL"
  log_destination = aws_cloudwatch_log_group.flow_log.arn

  tags = {
    Component   = "networking"
    Environment = "dev"
    App         = "sample-app"
  }
}
