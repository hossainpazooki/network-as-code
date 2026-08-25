# SEC-001 violation: the fourth deny clause - aws_security_group_rule with
# type=ingress opened to ::/0. Added 2026-08-24 after an adversarial review
# found this clause had only an `opa test` unit test and no fixture in the CI
# negative-control loop, so deleting the clause would not have turned CI red.

resource "aws_security_group_rule" "wide_open_v6" {
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  ipv6_cidr_blocks  = ["::/0"]
  security_group_id = "sg-0123456789abcdef0"
}
