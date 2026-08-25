package main

# =============================================================================
# SEC-001 - security group open to the world
#
# DENY any aws_security_group ingress block, or aws_security_group_rule with
# type == "ingress", whose cidr_blocks contains "0.0.0.0/0" or whose
# ipv6_cidr_blocks contains "::/0".
#
# EXPECTED HISTORICAL HITS: 0. Verified: the string 0.0.0.0/0 appears nowhere
# in the 12 vendored .tf files (fixtures/historical/terraform/*.tf) - the only
# ingress rules in that tree scope to security_groups (EKS node SG), never to
# a raw CIDR. This rule is proven by its negative control, not by a finding.
# =============================================================================

deny contains msg if {
	some name, i
	sg := input.resource.aws_security_group[name][i]
	some j
	block := sg.ingress[j]
	some k
	block.cidr_blocks[k] == "0.0.0.0/0"
	msg := sprintf("SEC-001: aws_security_group %s ingress cidr_blocks includes 0.0.0.0/0 (aws_security_group.%s)", [name, name])
}

deny contains msg if {
	some name, i
	sg := input.resource.aws_security_group[name][i]
	some j
	block := sg.ingress[j]
	some k
	block.ipv6_cidr_blocks[k] == "::/0"
	msg := sprintf("SEC-001: aws_security_group %s ingress ipv6_cidr_blocks includes ::/0 (aws_security_group.%s)", [name, name])
}

deny contains msg if {
	some name, i
	r := input.resource.aws_security_group_rule[name][i]
	r.type == "ingress"
	some k
	r.cidr_blocks[k] == "0.0.0.0/0"
	msg := sprintf("SEC-001: aws_security_group_rule %s (type=ingress) cidr_blocks includes 0.0.0.0/0 (aws_security_group_rule.%s)", [name, name])
}

deny contains msg if {
	some name, i
	r := input.resource.aws_security_group_rule[name][i]
	r.type == "ingress"
	some k
	r.ipv6_cidr_blocks[k] == "::/0"
	msg := sprintf("SEC-001: aws_security_group_rule %s (type=ingress) ipv6_cidr_blocks includes ::/0 (aws_security_group_rule.%s)", [name, name])
}

# =============================================================================
# SEC-002 - NetworkPolicy egress broader than the VPC
#
# DENY a NetworkPolicy whose spec.egress[_].to[_].ipBlock.cidr is NOT
# contained by the VPC CIDR, unless the policy carries a non-empty
# "policy.hossainpazooki.dev/egress-exemption" annotation.
#
# A NetworkPolicy YAML input has no access to variables.tf, so the VPC CIDR
# is pinned here as a constant. Source of truth:
#   fixtures/historical/terraform/variables.tf:146
#   variable "vpc_cidr" { default = "10.0.0.0/16" }
# SEC-002-DRIFT (below) fails the build the moment variables.tf declares a
# different default, so this constant cannot silently drift from the HCL.
# =============================================================================

vpc_cidr := "10.0.0.0/16"

exempted if {
	input.metadata.annotations["policy.hossainpazooki.dev/egress-exemption"] != ""
}

deny contains msg if {
	input.kind == "NetworkPolicy"
	some i
	egress := input.spec.egress[i]
	some j
	cidr := egress.to[j].ipBlock.cidr
	not net.cidr_contains(vpc_cidr, cidr)
	not exempted

	# `deny contains msg` is a SET - two occurrences with the same cidr on the
	# same policy (e.g. 10.0.0.0/8 opened separately to ports 5432 and 6379)
	# would render identical text and silently collapse to one finding. The
	# egress/to index pair keeps each occurrence distinct without depending on
	# port numbers being present.
	msg := sprintf("SEC-002: egress ipBlock %s is broader than the declared VPC CIDR %s (NetworkPolicy %s, egress[%d].to[%d])", [cidr, vpc_cidr, input.metadata.name, i, j])
}

# ---------------------------------------------------------------------------
# SEC-002-DRIFT - the vpc_cidr constant above must track variables.tf
#
# DENY when a variables.tf input (parsed as HCL2, so `variable` is a map of
# LISTS) declares a vpc_cidr default that does not equal the pinned constant.
# ---------------------------------------------------------------------------

deny contains msg if {
	some i
	v := input.variable.vpc_cidr[i]
	v.default != vpc_cidr
	msg := sprintf("SEC-002-DRIFT: variables.tf declares vpc_cidr default %s but policy/security.rego pins %s (variables.tf)", [v.default, vpc_cidr])
}
