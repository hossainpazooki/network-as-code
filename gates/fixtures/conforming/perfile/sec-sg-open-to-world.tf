# DELIBERATE VIOLATION, placed in the CONFORMING corpus on purpose.
#
# This file exists to be refused. It sits under fixtures/conforming/perfile/,
# the directory `./run.sh conforming` asserts must PASS every rule family, and
# it opens port 22 to the whole internet. SEC-001 must fire on it, and when it
# does the `conforming` job goes red and the pull request carrying this file
# cannot merge. That is the artifact: the gate blocking a merge, not merely
# refusing a fixture it was already expecting to refuse.
#
# Every other tag and argument is set so that NOTHING except SEC-001 has a
# reason to object - one violation, one finding, one red job.
resource "aws_security_group" "bastion" {
  name_prefix = "example-bastion-"
  description = "SSH from anywhere - this is the violation"
  vpc_id      = "vpc-example"

  ingress {
    description = "SSH open to the world"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Component   = "bastion"
    Environment = "dev"
    App         = "sample-app"
  }
}
