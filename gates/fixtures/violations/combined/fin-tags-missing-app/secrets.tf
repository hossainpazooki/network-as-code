# FIN-001 violation, file 2 of 2: Component is on the resource, Environment
# comes from default_tags in versions.tf, and App is supplied by nothing. This
# set must be REFUSED, and the message must name App and ONLY App.

resource "aws_secretsmanager_secret" "database" {
  name = "institutional-defi/database"

  tags = {
    Component = "secrets"
  }
}
