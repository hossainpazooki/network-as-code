# FIN-001 violation: a taggable resource type with no tags argument at all, in
# a set with no provider block, so nothing supplies any of the three required
# allocation tags. Must be REFUSED naming all three.

resource "aws_elasticache_subnet_group" "cache" {
  name       = "institutional-defi-cache"
  subnet_ids = ["subnet-aaaa", "subnet-bbbb"]
}
