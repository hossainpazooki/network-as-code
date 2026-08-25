# Violation: SEC-001 - aws_security_group_rule type=ingress, cidr_blocks 0.0.0.0/0.
resource "aws_security_group_rule" "wide_open" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "sg-example"
}
