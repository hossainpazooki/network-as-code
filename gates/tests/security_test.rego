package main

# All three rule families share `package main`, so the global `deny` set is the
# UNION of every family's findings. These mocks are minimal aws_* resources
# with no tags, so FIN-001 also fires on them: an unscoped `count(deny) > 0`
# would pass even if SEC-001 stopped firing, and an unscoped `count(deny) == 0`
# fails for a reason that has nothing to do with this family. Every assertion
# below is therefore scoped to this family's rule IDs.
sec_only(msgs) := {m | some m in msgs; startswith(m, "SEC-")}

# ------------------------------------------------------------- SEC-001 (v4)

test_sec001_denies_sg_ingress_open_v4 if {
	r := deny with input as {"resource": {"aws_security_group": {"bad": [{"ingress": [{"cidr_blocks": ["0.0.0.0/0"]}]}]}}}
	count(sec_only(r)) > 0
}

test_sec001_allows_sg_ingress_scoped if {
	r := deny with input as {"resource": {"aws_security_group": {"good": [{"ingress": [{"security_groups": ["sg-abc123"]}]}]}}}
	count(sec_only(r)) == 0
}

test_sec001_allows_sg_ingress_restricted_cidr if {
	r := deny with input as {"resource": {"aws_security_group": {"good": [{"ingress": [{"cidr_blocks": ["10.0.0.0/16"]}]}]}}}
	count(sec_only(r)) == 0
}

# ------------------------------------------------------------- SEC-001 (v6)

test_sec001_denies_sg_ingress_open_v6 if {
	r := deny with input as {"resource": {"aws_security_group": {"bad": [{"ingress": [{"ipv6_cidr_blocks": ["::/0"]}]}]}}}
	count(sec_only(r)) > 0
}

# ------------------------------------------------------- SEC-001 (rule form)

test_sec001_denies_sg_rule_ingress_open if {
	r := deny with input as {"resource": {"aws_security_group_rule": {"bad": [{"type": "ingress", "cidr_blocks": ["0.0.0.0/0"]}]}}}
	count(sec_only(r)) > 0
}

# The fourth SEC-001 clause (aws_security_group_rule + ipv6_cidr_blocks) had no
# refusing test of its own: it could have been deleted without turning anything
# red. A rule clause without a negative control is exactly what this repo exists
# to forbid.
test_sec001_denies_sg_rule_ingress_open_v6 if {
	r := deny with input as {"resource": {"aws_security_group_rule": {"bad": [{"type": "ingress", "ipv6_cidr_blocks": ["::/0"]}]}}}
	count(sec_only(r)) > 0
}

test_sec001_allows_sg_rule_egress_open if {
	# egress to 0.0.0.0/0 is not an ingress finding under SEC-001.
	r := deny with input as {"resource": {"aws_security_group_rule": {"ok": [{"type": "egress", "cidr_blocks": ["0.0.0.0/0"]}]}}}
	count(sec_only(r)) == 0
}

# ------------------------------------------------------------------ SEC-002

test_sec002_denies_egress_broader_than_vpc if {
	np := {
		"kind": "NetworkPolicy",
		"metadata": {"name": "egress-common"},
		"spec": {"egress": [{"to": [{"ipBlock": {"cidr": "10.0.0.0/8"}}]}]},
	}
	r := deny with input as np
	count(sec_only(r)) > 0
}

test_sec002_allows_egress_within_vpc if {
	np := {
		"kind": "NetworkPolicy",
		"metadata": {"name": "egress-scoped"},
		"spec": {"egress": [{"to": [{"ipBlock": {"cidr": "10.0.1.0/24"}}]}]},
	}
	r := deny with input as np
	count(sec_only(r)) == 0
}

test_sec002_exemption_annotation_suppresses_deny if {
	np := {
		"kind": "NetworkPolicy",
		"metadata": {
			"name": "egress-common",
			"annotations": {"policy.hossainpazooki.dev/egress-exemption": "reviewed, ADR-0031"},
		},
		"spec": {"egress": [{"to": [{"ipBlock": {"cidr": "0.0.0.0/0"}}]}]},
	}
	r := deny with input as np
	count(sec_only(r)) == 0
}

test_sec002_empty_exemption_annotation_does_not_suppress if {
	np := {
		"kind": "NetworkPolicy",
		"metadata": {
			"name": "egress-common",
			"annotations": {"policy.hossainpazooki.dev/egress-exemption": ""},
		},
		"spec": {"egress": [{"to": [{"ipBlock": {"cidr": "0.0.0.0/0"}}]}]},
	}
	r := deny with input as np
	count(sec_only(r)) > 0
}

test_sec002_ignores_non_ipblock_egress_targets if {
	np := {
		"kind": "NetworkPolicy",
		"metadata": {"name": "egress-dns"},
		"spec": {"egress": [{"to": [{"namespaceSelector": {}}]}]},
	}
	r := deny with input as np
	count(sec_only(r)) == 0
}

# ------------------------------------------------------------ SEC-002-DRIFT

test_sec002_drift_denies_changed_default if {
	tfvars := {"variable": {"vpc_cidr": [{"default": "10.0.0.0/8"}]}}
	r := deny with input as tfvars
	count(sec_only(r)) > 0
}

test_sec002_drift_allows_matching_default if {
	tfvars := {"variable": {"vpc_cidr": [{"default": "10.0.0.0/16"}]}}
	r := deny with input as tfvars
	count(sec_only(r)) == 0
}
