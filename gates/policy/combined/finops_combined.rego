package main

# =============================================================================
# FIN-001 - allocation tags (combined mode only)
#
# Mechanism: cost-per-application reporting is only computable if attribution
# is enforced at provision time. Every taggable aws_* resource in the set must
# carry Component, Environment and App.
#
# WHY THIS RULE LIVES IN COMBINED MODE (this is a correctness requirement, not
# a convenience). In Terraform, `provider "aws" { default_tags { tags = ... } }`
# is a property of the PROVIDER CONFIGURATION: it applies to every resource in
# the root module regardless of which .tf file declares the provider block or
# the resource. Which file a resource is written in is a source-layout choice
# with no semantic meaning. An earlier version of this rule ran per-file and
# credited default_tags only when the provider block appeared in the SAME
# parsed file; because conftest evaluates one file per policy evaluation, that
# version reported `Environment` missing on every resource in the vendored
# historical config even though versions.tf declares it provider-wide. Those
# findings were false, and a gate that reports untrue findings is what trains
# people to ignore it. Under `--combine` the whole root module is one input, so
# the provider fact can be evaluated where it actually holds.
#
# THE UNION IS COMPUTED, NEVER PINNED. The effective default_tags map is the
# union of every `default_tags` block declared by ANY file in the combined set.
# A hardcoded "these keys are always supplied" constant was considered and
# rejected: it would credit Environment even in a repo that never declares it,
# and it would make the same-file / other-file distinction untestable.
#
# PARSE SHAPE (docs/parse-shape.md, verified with `conftest parse`):
#   --combine  -> input is a LIST of {"path": ..., "contents": ...}
#   HCL2 blocks parse to LISTS:
#     contents.provider.aws                    -> LIST of provider blocks
#     contents.provider.aws[_].default_tags    -> LIST (nested block)
#     contents.provider.aws[_].default_tags[0].tags -> MAP
#     contents.resource.<type>.<name>          -> LIST of instance bodies
#   `tags` is an argument, so it keeps its natural MAP type.
#
# Only meaningful under `conftest test --combine <dir> --policy policy/combined`.
# =============================================================================

# Declared in the order the mechanism sentence lists them, so a message never
# needs a separate sort step.
fin001_required_tags := ["Component", "Environment", "App"]

# Resource types with no `tags` argument in the AWS provider schema at all.
# Hand-verified judgment call (this gate never fetches a live AWS schema),
# anchored on the types actually present in fixtures/historical/terraform:
# aws_ecr_lifecycle_policy and aws_secretsmanager_secret_version both parse
# with no `tags` key in any instance body. The rest are the same well-known
# category - policy/attachment/association resources that wrap another
# resource and carry no tags of their own. Kept short on purpose: an unlisted
# non-taggable type surfaces here as a visible FIN-001 finding rather than
# silently vanishing.
fin001_non_taggable_types := {
	"aws_ecr_lifecycle_policy",
	"aws_secretsmanager_secret_version",
	"aws_secretsmanager_secret_policy",
	"aws_iam_role_policy",
	"aws_iam_role_policy_attachment",
	"aws_iam_user_policy",
	"aws_iam_policy_attachment",
	"aws_route",
	"aws_route_table_association",
	"aws_security_group_rule",
}

# Union of every `default_tags { tags = {...} }` map declared on a
# `provider "aws"` block by ANY file in the combined set. Always defined
# (possibly {}) - comprehensions never fail, they just come back empty.
fin001_provider_default_tags := {k: v |
	some i
	block := input[i].contents.provider.aws[_]
	dt_blocks := object.get(block, "default_tags", [{}])
	tagmap := object.get(dt_blocks[0], "tags", {})
	some k, v in tagmap
}

fin001_missing_tags(effective) := [t |
	some t in fin001_required_tags
	not effective[t]
]

deny contains msg if {
	some i
	doc := input[i].contents

	some rtype
	startswith(rtype, "aws_")
	not fin001_non_taggable_types[rtype]
	some name
	instances := doc.resource[rtype][name]
	some j
	inst := instances[j]

	own_tags := object.get(inst, "tags", {})
	effective := object.union(fin001_provider_default_tags, own_tags)
	missing := fin001_missing_tags(effective)
	count(missing) > 0

	msg := sprintf(
		"FIN-001: %s.%s is missing required allocation tag(s) %s - cost-per-application reporting is only computable if attribution is enforced at provision time (%s)",
		[rtype, name, concat(", ", missing), input[i].path],
	)
}
