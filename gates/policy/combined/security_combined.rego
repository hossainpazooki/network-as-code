package main

# =============================================================================
# SEC-003 - egress policy without default-deny ingress (combined mode only)
#
# For a manifest set: DENY when the set contains at least one NetworkPolicy
# with "Egress" in spec.policyTypes but NO NetworkPolicy in the set
# establishes default-deny ingress (policyTypes contains "Ingress", an
# empty/absent ingress rule list, and an empty podSelector).
#
# `--combine` wraps every input into a LIST: [{"path":..., "contents":...}, ..].
# Only meaningful under `conftest test --combine ... --policy policy/combined`.
#
# EXPECTED HISTORICAL HITS: 1. Verified: the vendored tree has exactly two
# NetworkPolicies (kube/base/egress-common.yaml, kube/overlays/dev/egress-app.yaml),
# both Egress-only, zero Ingress-type - so this fires once for the whole set,
# not once per Egress policy.
# =============================================================================

egress_policy_paths contains path if {
	some i
	doc := input[i].contents
	doc.kind == "NetworkPolicy"
	"Egress" in doc.spec.policyTypes
	path := input[i].path
}

default_deny_ingress if {
	some i
	doc := input[i].contents
	doc.kind == "NetworkPolicy"
	"Ingress" in doc.spec.policyTypes
	count(object.get(doc.spec, "ingress", [])) == 0
	doc.spec.podSelector == {}
}

deny contains msg if {
	count(egress_policy_paths) > 0
	not default_deny_ingress
	msg := sprintf("SEC-003: NetworkPolicies with Egress policyTypes exist but no NetworkPolicy in the set establishes default-deny Ingress (%s)", [concat(", ", egress_policy_paths)])
}
