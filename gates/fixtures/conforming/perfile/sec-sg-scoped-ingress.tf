# A CONFORMING fixture must conform to EVERY family, not just its own: all
# three rule families load into package main, so FIN-001's allocation tags
# (Component/Environment/App) are required here too.
# Conforming: ingress scoped to a security group reference, no open CIDR.
# Mirrors fixtures/historical/terraform/rds.tf's aws_security_group.rds.
resource "aws_security_group" "rds" {
  name_prefix = "example-rds-"
  description = "Allow PostgreSQL access from EKS nodes"
  vpc_id      = "vpc-example"

  ingress {
    description     = "PostgreSQL from EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = ["sg-eks-nodes"]
  }

  tags = {
    Component   = "database"
    Environment = "dev"
    App         = "sample-app"
  }
}
