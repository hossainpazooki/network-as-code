# FIN-001 violation, file 2 of 2: the resource supplies App, default_tags
# supplies Environment, and Component is supplied by neither. Must be REFUSED
# with a message naming Component alone.

resource "aws_sqs_queue" "orphaned" {
  name = "institutional-defi-orphaned"

  tags = {
    App = "regulatory-workbench"
  }
}
