# Violation: SEC-001 - ingress cidr_blocks contains 0.0.0.0/0.
resource "aws_security_group" "wide_open" {
  name        = "wide-open"
  description = "Negative control for SEC-001"
  vpc_id      = "vpc-example"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
