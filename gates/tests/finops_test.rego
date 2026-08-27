package main

# =============================================================================
# FIN-002 - Infracost budget delta
#
# FIN-001 is a combined-mode rule; its tests live in
# tests/finops_combined_test.rego.
#
# All families share package `main`, so `deny` is the UNION across families.
# Every assertion below is scoped to this rule's ID prefix, so it can neither
# be satisfied nor broken by another family firing on the same mock.
# =============================================================================

fin002_only(msgs) := {m | some m in msgs; startswith(m, "FIN-002:")}

fin002_project(env, cost) := {"projects": [{"name": env, "breakdown": {"totalMonthlyCost": cost}}]}

# -----------------------------------------------------------------------------
# policy/budget.json is the enforced source; the embedded fallback is GATED,
# not trusted.
#
# `opa test policy tests` loads policy/budget.json as data (top-level keys
# become data.dev / data.prod), which is the same exposure `conftest test
# --data policy` gives the gate. So these two tests compare the rule's
# embedded copy against the JSON value-for-value: edit one and forget the
# other and this goes red, instead of the two silently disagreeing depending
# on whether --data was passed.
#
# HONEST LIMIT: an environment added to budget.json but NOT given a static
# clause in fin002_budget_max cannot be detected here. Enumerating
# budget.json's keys would need `object.keys(data)`, and any dynamic
# reference to `data` from inside package main is a compile error
# (rego_recursion_error - the reference includes data.main itself). The
# reverse direction - a clause whose data path is wrong or whose key is
# absent from the JSON - IS caught, by the second test.
# -----------------------------------------------------------------------------
test_fin002_embedded_budget_matches_budget_json if {
	fin002_embedded_budget.dev.monthly_usd_max == data.dev.monthly_usd_max
	fin002_embedded_budget.prod.monthly_usd_max == data.prod.monthly_usd_max
}

test_fin002_each_static_clause_resolves_to_its_budget_json_entry if {
	every env, cfg in {"dev": data.dev, "prod": data.prod} {
		fin002_budget_max(env) == cfg.monthly_usd_max
	}
}

# -----------------------------------------------------------------------------
# Threshold behaviour
# -----------------------------------------------------------------------------
# 594.416 is the measured single-NAT dev total (fixtures/conforming/perfile/
# fin-infracost-dev-single-nat.json); 660.116 the measured per-AZ total. The
# ceiling between them is 625.0 - see policy/budget.json for the derivation.
test_fin002_dev_under_threshold_pass if {
	r := deny with input as fin002_project("dev", "594.416")
	count(fin002_only(r)) == 0
}

test_fin002_dev_over_threshold_denied if {
	r := deny with input as fin002_project("dev", "660.116")
	msgs := fin002_only(r)
	count(msgs) == 1
	some msg in msgs
	contains(msg, "dev")
}

test_fin002_prod_under_threshold_pass if {
	r := deny with input as fin002_project("prod", "899.99")
	count(fin002_only(r)) == 0
}

test_fin002_prod_over_threshold_denied if {
	r := deny with input as fin002_project("prod", "900.01")
	count(fin002_only(r)) == 1
}

test_fin002_unmapped_environment_not_evaluated if {
	# An environment with no configured ceiling must not crash the rule and
	# must not be guessed at - it is simply left unevaluated.
	r := deny with input as fin002_project("staging", "999999.00")
	count(fin002_only(r)) == 0
}

test_fin002_environment_match_is_case_insensitive if {
	r := deny with input as fin002_project("DEV", "660.116")
	count(fin002_only(r)) == 1
}

test_fin002_prod_measured_total_is_under_threshold if {
	# 853.404 measured (fixtures/conforming/perfile/fin-infracost-prod.json);
	# 900.0 is that plus 5.5% headroom, no longer a placeholder.
	r := deny with input as fin002_project("prod", "853.404")
	count(fin002_only(r)) == 0
}

test_fin002_multiple_projects_each_evaluated if {
	r := deny with input as {"projects": [
		{"name": "dev", "breakdown": {"totalMonthlyCost": "594.416"}},
		{"name": "prod", "breakdown": {"totalMonthlyCost": "1000.00"}},
	]}
	msgs := fin002_only(r)
	count(msgs) == 1
	some msg in msgs
	contains(msg, "prod")
}

# -----------------------------------------------------------------------------
# data.<env> vs the embedded fallback
# -----------------------------------------------------------------------------
test_fin002_data_dev_is_authoritative_over_embedded if {
	# $700 is refused under the embedded 625, but must pass once data.dev
	# raises the ceiling - so the static data reference is what enforces.
	r := deny with input as fin002_project("dev", "700.00")
		with data.dev as {"monthly_usd_max": 999.0}
	count(fin002_only(r)) == 0
}

test_fin002_embedded_fallback_enforces_when_data_absent if {
	# data.dev emptied models a bare `conftest test` with no --data flag.
	# The embedded 625 must still refuse $700 rather than permit everything.
	r := deny with input as fin002_project("dev", "700.00") with data.dev as {}
	count(fin002_only(r)) == 1
}

# -----------------------------------------------------------------------------
# Money formatting. sprintf's %f verb refuses an int64 outright, so a budget
# written as `250` in JSON used to render as "$%!f(int64=250)" in the message.
# -----------------------------------------------------------------------------
test_fin002_usd_formats_an_integer_budget if {
	fin002_usd(250) == "250.00"
}

test_fin002_usd_formats_a_whole_float_budget if {
	fin002_usd(900.0) == "900.00"
}

test_fin002_usd_formats_a_fractional_cost if {
	fin002_usd(287.03) == "287.03"
}

test_fin002_message_has_no_format_error_even_with_an_integer_budget if {
	r := deny with input as fin002_project("dev", "287.03")
		with data.dev as {"monthly_usd_max": 250}
	msgs := fin002_only(r)
	count(msgs) == 1
	some msg in msgs
	not contains(msg, "%!")
	contains(msg, "$287.03")
	contains(msg, "$250.00")
}

# =============================================================================
# FIN-003 - breakdown integrity
#
# The rule exists because infracost exits 0 when it fails to load modules,
# priced nothing, and reports $0.00 - a number that satisfies every budget.
# =============================================================================

fin003_only(msgs) := {m | some m in msgs; startswith(m, "FIN-003:")}

fin003_diag := {"code": 102, "message": "could not load modules for path . open ../modules/iam/pod: no such file or directory", "data": null, "isError": true}

fin003_doc(meta, detected) := {"projects": [{
	"name": "dev",
	"metadata": meta,
	"summary": {"totalDetectedResources": detected},
	"breakdown": {"totalMonthlyCost": "0", "resources": []},
}]}

# --- the failure that motivated the rule: both legs fire at once -------------

test_fin003_broken_module_load_is_denied if {
	r := deny with input as fin003_doc({"path": ".", "errors": [fin003_diag]}, 0)
	count(fin003_only(r)) == 2
}

# --- each leg must fire on its own, or one is dead code ----------------------

test_fin003_errors_alone_are_denied if {
	r := deny with input as fin003_doc({"path": ".", "errors": [fin003_diag]}, 12)
	count(fin003_only(r)) == 1
}

test_fin003_zero_detected_alone_is_denied if {
	r := deny with input as fin003_doc({"path": "."}, 0)
	count(fin003_only(r)) == 1
}

# --- a healthy breakdown must pass ------------------------------------------

test_fin003_healthy_breakdown_passes if {
	r := deny with input as fin003_doc({"path": "."}, 12)
	count(fin003_only(r)) == 0
}

test_fin003_empty_errors_array_passes if {
	r := deny with input as fin003_doc({"path": ".", "errors": []}, 12)
	count(fin003_only(r)) == 0
}

# --- FIN-003 must not leak into FIN-002's minimal test inputs ----------------
#
# fin002_project/2 builds {projects:[{name, breakdown}]} with no metadata and
# no summary. If FIN-003 bound on those, every FIN-002 test would carry a
# spurious second message and the two rules would be entangled. Asserted here
# rather than assumed, because the coupling would be silent.

test_fin003_does_not_fire_on_fin002_minimal_input if {
	r := deny with input as fin002_project("dev", "594.416")
	count(fin003_only(r)) == 0
}

# --- the zero-cost trap, stated as a test -----------------------------------
#
# The whole point: a broken parse reports "0", which is under the dev ceiling,
# so FIN-002 alone ACCEPTS it. FIN-003 is what refuses it. If FIN-002 ever
# started catching this on its own, this test would fail and the rule's
# justification would need rewriting.

test_fin003_is_what_catches_the_zero_cost_trap if {
	broken := fin003_doc({"path": ".", "errors": [fin003_diag]}, 0)
	r := deny with input as broken
	count(fin002_only(r)) == 0
	count(fin003_only(r)) > 0
}
