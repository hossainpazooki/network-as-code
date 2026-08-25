# FIN-001 conforming: all three required allocation tags are declared directly
# on the resource's own tags map, so no provider default_tags credit is needed
# for this set to pass.

resource "aws_s3_bucket" "reports" {
  bucket = "institutional-defi-reports"

  tags = {
    Component   = "reporting"
    Environment = "prod"
    App         = "regulatory-workbench"
  }
}
