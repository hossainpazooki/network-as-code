# FIN-001 conforming, file 2 of 2. The resource's own tags supply Component
# and App. Environment is supplied by the provider block in versions.tf, a
# DIFFERENT file in the same root module. This set must PASS - if it is ever
# refused, FIN-001 has regressed to the per-file semantics that produced false
# "missing Environment" findings against the historical config.

resource "aws_sqs_queue" "events" {
  name = "institutional-defi-events"

  tags = {
    Component = "messaging"
    App       = "regulatory-workbench"
  }
}
