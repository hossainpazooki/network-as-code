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
test_fin002_dev_under_threshold_pass if {
	r := deny with input as fin002_project("dev", "221.33")
	count(fin002_only(r)) == 0
}

test_fin002_dev_over_threshold_denied if {
	r := deny with input as fin002_project("dev", "287.03")
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
	r := deny with input as fin002_project("DEV", "287.03")
	count(fin002_only(r)) == 1
}

test_fin002_multiple_projects_each_evaluated if {
	r := deny with input as {"projects": [
		{"name": "dev", "breakdown": {"totalMonthlyCost": "221.33"}},
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
	# $260 is refused under the embedded 250, but must pass once data.dev
	# raises the ceiling - so the static data reference is what enforces.
	r := deny with input as fin002_project("dev", "260.00")
		with data.dev as {"monthly_usd_max": 999.0}
	count(fin002_only(r)) == 0
}

test_fin002_embedded_fallback_enforces_when_data_absent if {
	# data.dev emptied models a bare `conftest test` with no --data flag.
	# The embedded 250 must still refuse $260 rather than permit everything.
	r := deny with input as fin002_project("dev", "260.00") with data.dev as {}
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
