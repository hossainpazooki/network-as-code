package main

# =============================================================================
# FinOps family (prefix "fin")
#
# FIN-001 - allocation tags     -> policy/combined/finops_combined.rego
#           NOT in this file, and deliberately not duplicated here in a
#           weakened per-file form: two rules sharing one ID is its own lie.
#           default_tags is a property of the PROVIDER CONFIGURATION and
#           applies to the whole root module, so the rule can only be true in
#           --combine mode. See that file for the full argument.
# FIN-002 - Infracost budget delta (this file; per-file, one breakdown JSON
#           is one input)
# =============================================================================

# -----------------------------------------------------------------------------
# FIN-002 - budget delta
#
# DENY when a committed Infracost breakdown JSON shows a projected monthly
# cost above the ceiling declared for that project's environment. Real
# Infracost 0.10.x schema: top-level "projects" array, each with "name" and
# "breakdown.totalMonthlyCost" (a decimal STRING).
#
# Environment is read from the project's own `name` (Infracost is commonly
# invoked per-environment with `--project-name <env>`, e.g. "dev"/"prod").
# A project whose name matches no configured environment is one this rule
# cannot safely evaluate, so it is left unevaluated rather than guessed at.
#
# WHERE THE NUMBERS COME FROM. policy/budget.json is the enforced source:
# run.sh passes `--data policy` on every conftest invocation, which exposes
# budget.json's top-level keys as `data.dev` / `data.prod` (the file name is
# never part of the namespace, and the directory prefix is empty because
# budget.json sits at the root of the --data tree). `opa test policy tests`
# loads it the same way, so the unit tests below read the same numbers CI
# enforces.
#
# TWO CONSTRAINTS SHAPE THE LOOKUP BELOW, both verified rather than assumed:
#
# 1. The data reference must be STATIC. A DYNAMIC one - `data[env]` - is a
#    compile error inside package main, not a runtime miss:
#      rego_recursion_error: rule data.main.deny is recursive
#    because `data[env]` with an unbound-at-compile-time key includes
#    data.main itself. So each environment gets its own explicitly named
#    `data.<env>` clause. Adding an environment means adding a clause here
#    AND a key to budget.json; the sync test below fails if only one is done.
#
# 2. There is still an embedded fallback, so a bare `conftest test` with no
#    --data flag enforces something rather than silently permitting every
#    cost. The fallback is NOT hand-synced on trust: the unit test
#    `test_fin002_embedded_budget_matches_budget_json` asserts the embedded
#    map equals budget.json value-for-value, so a drifting copy fails the
#    gate instead of quietly overriding it.
# -----------------------------------------------------------------------------

# Fallback for a bare `conftest test` run with no `--data policy`. Gated
# against policy/budget.json by a unit test - see note 2 above.
fin002_embedded_budget := {
	"dev": {"monthly_usd_max": 250.0},
	"prod": {"monthly_usd_max": 900.0},
}

# STATIC data references only (see note 1). One clause per environment.
fin002_budget_max(env) := max_usd if {
	env == "dev"
	max_usd := data.dev.monthly_usd_max
} else := max_usd if {
	env == "prod"
	max_usd := data.prod.monthly_usd_max
} else := max_usd if {
	max_usd := fin002_embedded_budget[env].monthly_usd_max
}

# Render a USD amount with two decimals whichever way the number arrived.
# sprintf's %f verb REFUSES an int64 outright - it renders the literal text
# "%!f(int64=250)" - and JSON `250` in budget.json parses as an int while
# `250.0` and to_number("287.03") parse as floats. Arithmetic does not help:
# OPA normalises 250 * 1.0 straight back to an int. So a whole number is
# round-tripped through its own decimal text to force a float, and anything
# already fractional is formatted directly.
fin002_usd(n) := s if {
	round(n) == n
	s := sprintf("%.2f", [to_number(sprintf("%v.0", [n]))])
} else := sprintf("%.2f", [n])

deny contains msg if {
	some p
	project := input.projects[p]
	env := lower(trim_space(project.name))
	max_usd := fin002_budget_max(env)
	cost := to_number(project.breakdown.totalMonthlyCost)
	cost > max_usd

	msg := sprintf(
		"FIN-002: projected monthly cost $%s for Infracost project %q exceeds the %s budget of $%s",
		[fin002_usd(cost), project.name, env, fin002_usd(max_usd)],
	)
}
