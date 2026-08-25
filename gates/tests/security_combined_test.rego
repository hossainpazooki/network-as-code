package main

# SEC-003 rules live in policy/combined/security_combined.rego but are still
# package main; combined mode input is a LIST of {"path","contents"}.

egress_only_doc := {
	"path": "kube/base/egress-common.yaml",
	"contents": {
		"kind": "NetworkPolicy",
		"metadata": {"name": "egress-common"},
		"spec": {"podSelector": {}, "policyTypes": ["Egress"], "egress": []},
	},
}

second_egress_only_doc := {
	"path": "kube/overlays/dev/egress-app.yaml",
	"contents": {
		"kind": "NetworkPolicy",
		"metadata": {"name": "egress-app"},
		"spec": {"podSelector": {}, "policyTypes": ["Egress"], "egress": []},
	},
}

default_deny_ingress_doc := {
	"path": "kube/base/ingress-default-deny.yaml",
	"contents": {
		"kind": "NetworkPolicy",
		"metadata": {"name": "default-deny-ingress"},
		"spec": {"podSelector": {}, "policyTypes": ["Ingress"]},
	},
}

not_default_deny_because_scoped_selector_doc := {
	"path": "kube/base/ingress-scoped.yaml",
	"contents": {
		"kind": "NetworkPolicy",
		"metadata": {"name": "ingress-scoped"},
		"spec": {"podSelector": {"matchLabels": {"app": "api"}}, "policyTypes": ["Ingress"]},
	},
}

test_sec003_denies_egress_only_set_with_no_default_deny if {
	r := deny with input as [egress_only_doc, second_egress_only_doc]
	count(r) > 0
}

test_sec003_fires_once_for_multiple_egress_only_policies if {
	# Two Egress-only policies, still exactly one SEC-003 message for the set.
	r := deny with input as [egress_only_doc, second_egress_only_doc]
	count(r) == 1
}

test_sec003_allows_set_with_default_deny_ingress if {
	r := deny with input as [egress_only_doc, default_deny_ingress_doc]
	count(r) == 0
}

test_sec003_scoped_ingress_policy_does_not_count_as_default_deny if {
	r := deny with input as [egress_only_doc, not_default_deny_because_scoped_selector_doc]
	count(r) > 0
}

test_sec003_allows_set_with_no_egress_policies_at_all if {
	r := deny with input as [default_deny_ingress_doc]
	count(r) == 0
}
