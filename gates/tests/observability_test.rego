package main

# All three rule families share `package main`, so the global `deny` set is the
# UNION of every family's findings — FIN-001 fires on these untagged aws_vpc /
# aws_ecr_repository mocks. Counting the whole set would make an OBS assertion
# depend on the FinOps tag list, so every count below is scoped to OBS rule IDs.
# The no-double-counting guarantee is unchanged: it is still "exactly one OBS
# finding", now stated as exactly that.
obs_only(msgs) := {m | some m in msgs; startswith(m, "OBS-")}

# ---------------------------------------------------------------------------
# OBS-001 — no flow logs at all.
# ---------------------------------------------------------------------------

test_obs001_module_no_flow_log_denied if {
	mock_input := {"module": {"vpc": [{
		"source": "terraform-aws-modules/vpc/aws",
		"version": "~> 5.0",
	}]}}
	msgs := deny with input as mock_input
	count(obs_only(msgs)) == 1
	some m in obs_only(msgs)
	startswith(m, "OBS-001: module \"vpc\"")
}

test_obs001_resource_no_flow_log_denied if {
	mock_input := {"resource": {"aws_vpc": {"main": [{"cidr_block": "10.1.0.0/16"}]}}}
	msgs := deny with input as mock_input
	count(obs_only(msgs)) == 1
	some m in obs_only(msgs)
	startswith(m, "OBS-001: resource aws_vpc.main")
}

# A module with an unresolved (variable-driven) enable_flow_log cannot be
# credited as enabled — the parser never resolves "${var.x}" — so OBS-001
# still fires. This is the honest-indeterminate behaviour documented in
# policy/observability.rego, not a false positive.
test_obs001_module_unresolved_flag_still_denied if {
	mock_input := {"module": {"vpc": [{
		"source":         "terraform-aws-modules/vpc/aws",
		"enable_flow_log": "${var.enable_flow_log}",
	}]}}
	msgs := deny with input as mock_input
	count(obs_only(msgs)) == 1
}

test_obs001_non_vpc_module_not_denied if {
	mock_input := {"module": {"redis": [{"source": "terraform-aws-modules/elasticache/aws"}]}}
	msgs := deny with input as mock_input
	count(obs_only(msgs)) == 0
}

test_obs001_unrelated_resource_not_denied if {
	mock_input := {"resource": {"aws_ecr_repository": {"app": [{"name": "sample-app"}]}}}
	msgs := deny with input as mock_input
	count(obs_only(msgs)) == 0
}

# ---------------------------------------------------------------------------
# OBS-002 — flow logs enabled, no retention. Must be gated on OBS-001 NOT
# firing: a VPC with no flow logs at all yields exactly one message total,
# never two.
# ---------------------------------------------------------------------------

test_obs002_module_flow_log_no_retention_denied if {
	mock_input := {"module": {"vpc": [{
		"source":          "terraform-aws-modules/vpc/aws",
		"enable_flow_log": true,
	}]}}
	msgs := deny with input as mock_input
	count(obs_only(msgs)) == 1
	some m in obs_only(msgs)
	startswith(m, "OBS-002: module \"vpc\"")
}

test_obs002_resource_flow_log_no_retention_denied if {
	mock_input := {"resource": {
		"aws_vpc": {"main": [{"cidr_block": "10.1.0.0/16"}]},
		"aws_flow_log": {"main": [{"vpc_id": "${aws_vpc.main.id}"}]},
	}}
	msgs := deny with input as mock_input
	count(obs_only(msgs)) == 1
	some m in obs_only(msgs)
	startswith(m, "OBS-002: aws_vpc.main")
}

# The no-double-counting guarantee, asserted directly: a module with NO flow
# logs at all must yield exactly 1 finding (OBS-001), never OBS-001 AND
# OBS-002 together.
test_obs001_and_obs002_do_not_double_count if {
	mock_input := {"module": {"vpc": [{"source": "terraform-aws-modules/vpc/aws"}]}}
	msgs := deny with input as mock_input
	count(obs_only(msgs)) == 1
	obs_only(msgs) == {"OBS-001: module \"vpc\" (AWS VPC module) has no flow logs enabled — without flow logs there is no record of what the network actually did, so an egress policy can only be reasoned about, never audited (module.vpc)"}
}

# Same guarantee on the bare-resource path.
test_obs001_and_obs002_do_not_double_count_resource if {
	mock_input := {"resource": {"aws_vpc": {"main": [{"cidr_block": "10.1.0.0/16"}]}}}
	msgs := deny with input as mock_input
	count(obs_only(msgs)) == 1
}

# A retention period declared through an unresolved variable reference is not
# a literal number, so it cannot be credited — OBS-002 still fires.
test_obs002_unresolved_retention_still_denied if {
	mock_input := {"module": {"vpc": [{
		"source":                                          "terraform-aws-modules/vpc/aws",
		"enable_flow_log":                                 true,
		"flow_log_cloudwatch_log_group_retention_in_days": "${var.retention}",
	}]}}
	msgs := deny with input as mock_input
	count(obs_only(msgs)) == 1
	some m in obs_only(msgs)
	startswith(m, "OBS-002:")
}

# ---------------------------------------------------------------------------
# Conforming — flow logs enabled AND retention declared: no findings at all.
# ---------------------------------------------------------------------------

test_conforming_module_flow_logs_with_retention if {
	mock_input := {"module": {"vpc": [{
		"source":                                          "terraform-aws-modules/vpc/aws",
		"enable_flow_log":                                 true,
		"flow_log_cloudwatch_log_group_retention_in_days": 30,
	}]}}
	msgs := deny with input as mock_input
	count(obs_only(msgs)) == 0
}

test_conforming_resource_flow_logs_with_retention if {
	mock_input := {"resource": {
		"aws_vpc":                 {"main": [{"cidr_block": "10.1.0.0/16"}]},
		"aws_flow_log":            {"main": [{"vpc_id": "${aws_vpc.main.id}"}]},
		"aws_cloudwatch_log_group": {"flow_log": [{"retention_in_days": 90}]},
	}}
	msgs := deny with input as mock_input
	count(obs_only(msgs)) == 0
}
