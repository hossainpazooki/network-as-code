# Violation: SEC-001 - ingress ipv6_cidr_blocks contains ::/0.
resource "aws_security_group" "wide_open_v6" {
  name        = "wide-open-v6"
  description = "Negative control for SEC-001 (IPv6)"
  vpc_id      = "vpc-example"

  ingress {
    from_port        = 22
    to_port           = 22
    protocol          = "tcp"
    ipv6_cidr_blocks  = ["::/0"]
  }
}
