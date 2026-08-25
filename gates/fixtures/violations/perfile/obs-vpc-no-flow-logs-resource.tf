# OBS-001 violation: a bare aws_vpc resource (not via the module) with no
# aws_flow_log resource anywhere in this file.

resource "aws_vpc" "main" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Component = "networking"
  }
}
