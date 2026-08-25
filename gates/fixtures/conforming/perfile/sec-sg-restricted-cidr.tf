# A CONFORMING fixture must conform to EVERY family, not just its own: all
# three rule families load into package main, so FIN-001's allocation tags
# (Component/Environment/App) are required here too.
# Conforming: cidr_blocks present but scoped to the VPC, never 0.0.0.0/0.
resource "aws_security_group" "bastion" {
  name        = "bastion"
  description = "Allow SSH from within the VPC only"
  vpc_id      = "vpc-example"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  tags = {
    Component   = "network"
    Environment = "dev"
    App         = "sample-app"
  }
}
