package main

# =============================================================================
# FIN-001 - allocation tags (combined mode)
#
# The rule lives in policy/combined/finops_combined.rego but is still package
# main, so `deny` is the union across families. Every assertion is scoped to
# the FIN-001 prefix.
#
# Combined-mode input is a LIST of {"path", "contents"}; HCL2 blocks inside
# `contents` are LISTS (docs/parse-shape.md).
# =============================================================================

fin001_only(msgs) := {m | some m in msgs; startswith(m, "FIN-001:")}

provider_doc(tags) := {
	"path": "terraform/versions.tf",
	"contents": {"provider": {"aws": [{"region": "us-east-1", "default_tags": [{"tags": tags}]}]}},
}

resource_doc(path, rtype, name, body) := {
	"path": path,
	"contents": {"resource": {rtype: {name: [body]}}},
}

# ---------------------------------------------------------------- conforming

test_fin001_all_three_tags_on_the_resource_pass if {
	r := deny with input as [resource_doc("terraform/s3.tf", "aws_s3_bucket", "reports", {"tags": {
		"Component": "reporting",
		"Environment": "prod",
		"App": "regulatory-workbench",
	}})]
	count(fin001_only(r)) == 0
}

# THE CASE THE PER-FILE RULE GOT WRONG. This is the vendored historical
# layout: the provider block is in versions.tf and the resource is in another
# file entirely. default_tags is a property of the provider configuration and
# applies to the whole root module, so Environment IS attributed and this set
# must PASS.
test_fin001_default_tags_from_a_different_file_credits_environment if {
	r := deny with input as [
		provider_doc({"Environment": "${var.environment}", "ManagedBy": "terraform"}),
		resource_doc("terraform/sqs.tf", "aws_sqs_queue", "events", {"tags": {
			"Component": "messaging",
			"App": "regulatory-workbench",
		}}),
	]
	count(fin001_only(r)) == 0
}

test_fin001_default_tags_in_the_same_file_still_credits_environment if {
	r := deny with input as [{
		"path": "terraform/all-in-one.tf",
		"contents": {
			"provider": {"aws": [{"default_tags": [{"tags": {"Environment": "dev"}}]}]},
			"resource": {"aws_sqs_queue": {"events": [{"tags": {
				"Component": "messaging",
				"App": "regulatory-workbench",
			}}]}},
		},
	}]
	count(fin001_only(r)) == 0
}

test_fin001_non_taggable_resource_type_skipped if {
	r := deny with input as [resource_doc("terraform/ecr.tf", "aws_ecr_lifecycle_policy", "example", {"repository": "x"})]
	count(fin001_only(r)) == 0
}

test_fin001_non_aws_resource_type_ignored if {
	r := deny with input as [resource_doc("terraform/k8s.tf", "kubernetes_namespace", "ns", {"metadata": [{"name": "x"}]})]
	count(fin001_only(r)) == 0
}

test_fin001_empty_set_finds_nothing if {
	r := deny with input as []
	count(fin001_only(r)) == 0
}

# ---------------------------------------------------------------- refusing

test_fin001_missing_app_denied_and_names_only_app if {
	r := deny with input as [
		provider_doc({"Environment": "${var.environment}", "ManagedBy": "terraform"}),
		resource_doc("terraform/secrets.tf", "aws_secretsmanager_secret", "database", {"tags": {"Component": "secrets"}}),
	]
	msgs := fin001_only(r)
	count(msgs) == 1
	some msg in msgs
	contains(msg, "aws_secretsmanager_secret.database")
	contains(msg, "tag(s) App -")
	contains(msg, "terraform/secrets.tf")
}

test_fin001_default_tags_credit_is_tag_by_tag_not_a_blanket_pass if {
	# default_tags supplies Environment from another file, the resource
	# supplies App, and nothing supplies Component - so this is still refused,
	# and the message must name Component ALONE.
	r := deny with input as [
		provider_doc({"Environment": "dev", "ManagedBy": "terraform"}),
		resource_doc("terraform/sqs.tf", "aws_sqs_queue", "orphaned", {"tags": {"App": "regulatory-workbench"}}),
	]
	msgs := fin001_only(r)
	count(msgs) == 1
	some msg in msgs
	contains(msg, "tag(s) Component -")
	not contains(msg, "Environment")
	not contains(msg, "App -")
}

test_fin001_no_provider_block_means_no_credit_at_all if {
	r := deny with input as [resource_doc("terraform/cache.tf", "aws_elasticache_subnet_group", "cache", {"subnet_ids": ["a", "b"]})]
	msgs := fin001_only(r)
	count(msgs) == 1
	some msg in msgs
	contains(msg, "Component, Environment, App")
}

# The union is COMPUTED from the set, never pinned: an unrelated repo that
# declares default_tags carrying only ManagedBy must NOT get Environment for
# free. This is the test a hardcoded "pinned default_tags keys" constant would
# make impossible to write.
test_fin001_environment_not_credited_when_no_file_declares_it if {
	r := deny with input as [
		provider_doc({"ManagedBy": "terraform", "Project": "x"}),
		resource_doc("terraform/sqs.tf", "aws_sqs_queue", "events", {"tags": {
			"Component": "messaging",
			"App": "regulatory-workbench",
		}}),
	]
	msgs := fin001_only(r)
	count(msgs) == 1
	some msg in msgs
	contains(msg, "tag(s) Environment -")
}

test_fin001_default_tags_union_spans_several_provider_files if {
	r := deny with input as [
		provider_doc({"Environment": "dev"}),
		{
			"path": "terraform/versions-extra.tf",
			"contents": {"provider": {"aws": [{"default_tags": [{"tags": {"Component": "platform"}}]}]}},
		},
		resource_doc("terraform/sqs.tf", "aws_sqs_queue", "events", {"tags": {"App": "x"}}),
	]
	count(fin001_only(r)) == 0
}

test_fin001_each_resource_flagged_independently if {
	r := deny with input as [
		provider_doc({"Environment": "dev"}),
		{
			"path": "terraform/secrets.tf",
			"contents": {"resource": {"aws_secretsmanager_secret": {
				"ok": [{"tags": {"Component": "secrets", "App": "x"}}],
				"bad": [{"tags": {"Component": "secrets"}}],
			}}},
		},
	]
	msgs := fin001_only(r)
	count(msgs) == 1
	some msg in msgs
	contains(msg, "aws_secretsmanager_secret.bad")
}

test_fin001_message_names_the_file_the_resource_is_declared_in if {
	r := deny with input as [
		provider_doc({"Environment": "dev"}),
		resource_doc("terraform/ecr.tf", "aws_ecr_repository", "regulatory_workbench", {"tags": {"Component": "registry"}}),
	]
	some msg in fin001_only(r)
	contains(msg, "(terraform/ecr.tf)")
}
