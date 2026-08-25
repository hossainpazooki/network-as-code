package main

# OBS-001 / OBS-002 — flow-log observability for VPCs.
#
# Parse-shape facts this rule is written against (see docs/parse-shape.md):
#   input.module.<name>            -> LIST of blocks
#   input.resource.<type>.<name>   -> LIST of blocks
#   arguments (not blocks) keep their natural JSON type: bool, number, string
#   unresolved expressions ("${var.x}", "${...}") arrive as opaque strings and
#   are never evaluated — a flag or a retention period set through a variable
#   reference cannot be credited as a literal true / a literal number, and is
#   treated as undeclared. That is a deliberate, honest choice, not a gap.

# ---------------------------------------------------------------------------
# OBS-001 — a VPC (module or bare resource) with no flow logs at all.
# ---------------------------------------------------------------------------

deny contains msg if {
	some name, i
	mod := input.module[name][i]
	contains(mod.source, "terraform-aws-modules/vpc/aws")
	not vpc_module_flow_log_enabled(mod)
	not any_flow_log_resource
	msg := sprintf("OBS-001: module %q (AWS VPC module) has no flow logs enabled — without flow logs there is no record of what the network actually did, so an egress policy can only be reasoned about, never audited (module.%s)", [name, name])
}

deny contains msg if {
	some name, i
	input.resource.aws_vpc[name][i]
	not any_flow_log_resource
	msg := sprintf("OBS-001: resource aws_vpc.%s has no flow logs enabled — without flow logs there is no record of what the network actually did, so an egress policy can only be reasoned about, never audited (aws_vpc.%s)", [name, name])
}

# A module's own `enable_flow_log = true` argument. Anything other than the
# literal boolean true (missing, false, or an unresolved "${...}" reference)
# does not count — it cannot be shown to be enabled from the static parse.
vpc_module_flow_log_enabled(mod) if {
	mod.enable_flow_log == true
}

# A standalone aws_flow_log resource anywhere in this input file. Present at
# all is enough for OBS-001 (it doesn't matter which vpc_id it targets — the
# parser never resolves that reference either); OBS-002 below is what checks
# whether it is actually configured with a retention period.
any_flow_log_resource if {
	count(object.get(input, ["resource", "aws_flow_log"], {})) > 0
}

# ---------------------------------------------------------------------------
# OBS-002 — flow logs enabled, but no explicit retention period declared.
# Each rule here is gated on flow logs actually being enabled for that same
# VPC entity, which is exactly the condition under which the matching OBS-001
# rule above does NOT fire. A VPC with no flow logs at all therefore produces
# exactly one finding (OBS-001), never two.
# ---------------------------------------------------------------------------

deny contains msg if {
	some name, i
	mod := input.module[name][i]
	contains(mod.source, "terraform-aws-modules/vpc/aws")
	vpc_module_flow_log_enabled(mod)
	not vpc_module_retention_set(mod)
	not any_log_group_retention_set
	msg := sprintf("OBS-002: module %q enables flow logs but declares no retention period for the flow-log CloudWatch log group (module.%s)", [name, name])
}

deny contains msg if {
	some name, i
	input.resource.aws_vpc[name][i]
	any_flow_log_resource
	not any_log_group_retention_set
	msg := sprintf("OBS-002: aws_vpc.%s has flow logs enabled via aws_flow_log but no retention period is declared for its CloudWatch log group (aws_vpc.%s)", [name, name])
}

# The AWS VPC module's own retention argument, as a literal number.
vpc_module_retention_set(mod) if {
	is_number(mod.flow_log_cloudwatch_log_group_retention_in_days)
}

# Any standalone aws_cloudwatch_log_group resource in this input file that
# declares a literal-number retention_in_days. Not scoped to a particular
# flow-log resource's log_destination — that reference is itself usually an
# unresolved expression per the parse shape above, so the honest check is
# "does this file declare a retention period anywhere a log group could use
# one", not a resolved graph edge the parser cannot give us.
any_log_group_retention_set if {
	some name, i
	lg := input.resource.aws_cloudwatch_log_group[name][i]
	is_number(lg.retention_in_days)
}
