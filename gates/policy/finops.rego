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
# FIN-003 - breakdown integrity: the tool could not evaluate (this file)
# FIN-004 - breakdown schema: the policy cannot read what the tool wrote
#           (this file)
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
	"dev": {"monthly_usd_max": 625.0},
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

# -----------------------------------------------------------------------------
# FIN-003 - breakdown integrity
#
# DENY when a committed Infracost breakdown JSON is not a usable measurement:
# it carries evaluation errors, or it detected no resources at all.
#
# WHY THIS RULE EXISTS. On 2026-08-26 `infracost breakdown` was run against
# fixtures/historical/terraform for the first time. iam.tf sources three local
# modules at ../modules/iam/*, which sit one directory ABOVE the vendored tree
# and were never vendored with it. Infracost could not load them, priced
# nothing, printed "No cloud resources were detected", reported a
# totalMonthlyCost of "0" - and EXITED 0.
#
# That is the entire problem. A cost ceiling compares a number against a
# budget; a failed parse produces the number 0; 0 is under every budget. FIN-002
# would have approved that file forever, and the exit code raises no objection.
# This is the same defect class as conftest's own exit code, already recorded in
# docs/learnings/2026-08-25-conftest-exit-code-cannot-distinguish-error-from-refusal.md:
# a tool reporting "I could not evaluate this" down the same channel it uses for
# "this is fine".
#
# Both signals below are OBSERVED, not assumed:
#   - projects[].metadata.errors  - absent on all three successful runs,
#     present on the failed one. Shape taken from infracost's own schema:
#     []*ProjectDiag = {code, message, data, isError}, where code 102 is
#     diagModuleEvaluationFailure (internal/schema/project.go).
#   - projects[].summary.totalDetectedResources - 99, 107 and 107 on the
#     successful runs (re-read from the committed measured fixtures on
#     2026-08-27; an earlier revision of this comment said 12/14/14, which
#     is totalSupportedResources, a different field); 0 on the failed one.
#
# Each leg requires a key that the FIN-002 unit-test helper does not set, so
# this rule cannot fire on the minimal {projects:[{name,breakdown}]} inputs
# those tests construct. That is deliberate, and asserted below.
# -----------------------------------------------------------------------------

deny contains msg if {
	some p
	project := input.projects[p]
	errs := project.metadata.errors
	count(errs) > 0

	msg := sprintf(
		"FIN-003: Infracost breakdown for project %q carries %d evaluation error(s), first [code %v] %q - a cost gate reading a failed parse approves everything, because a failed parse costs $0.00",
		[project.name, count(errs), errs[0].code, errs[0].message],
	)
}

deny contains msg if {
	some p
	project := input.projects[p]
	project.summary.totalDetectedResources == 0

	msg := sprintf(
		"FIN-003: Infracost breakdown for project %q detected zero resources - infracost exits 0 after a failed module load and reports $0.00, so this file would satisfy any budget ceiling",
		[project.name],
	)
}

# -----------------------------------------------------------------------------
# FIN-004 - breakdown schema
#
# DENY when a file that carries a `projects` array - the signature of an
# Infracost breakdown - contains NO project in the shape FIN-002 reads:
# `projects[].name` together with `projects[].breakdown.totalMonthlyCost`.
#
# WHY. FIN-002 is bound to the Infracost v0.10.x JSON schema, and the binding
# is invisible at the call site: nothing in this policy names a version.
# Infracost v2 renamed both paths (`project_name`, `summary.total_monthly_cost`,
# verified from source on 2026-08-26). Against a v2 breakdown FIN-002 does not
# error - the reference is simply undefined, the deny body never binds, and
# every cost is approved. The v0.10 CLI prints a banner offering that upgrade
# as routine. So the failure mode is a green cost gate reading a file it cannot
# see, triggered by a version bump; FIN-003 covers "the tool could not
# evaluate", this covers "the policy cannot read what the tool wrote". Own ID,
# because the cause and the fix are different.
#
# ANCHOR, stated as a limit: this keys on the `projects` key existing. A future
# schema that renames `projects` itself would not be caught here. The committed
# fixtures carry a `_provenance` block naming the generating version, which is
# the human-readable half of the same pin.
# -----------------------------------------------------------------------------

fin004_expected_shape(p) if {
	p.name
	p.breakdown.totalMonthlyCost
}

fin004_first_project_keys := sort([k | some k, _ in input.projects[0]]) if {
	count(input.projects) > 0
} else := ["(no projects)"]

deny contains msg if {
	input.projects
	matching := [p | some p in input.projects; fin004_expected_shape(p)]
	count(matching) == 0

	msg := sprintf(
		"FIN-004: no project in this Infracost breakdown has the shape FIN-002 reads (projects[].name + projects[].breakdown.totalMonthlyCost, the v0.10.x schema) - %d project(s) present, keys of the first: %v - an unrecognised schema would otherwise match nothing and approve every cost",
		[count(input.projects), fin004_first_project_keys],
	)
}
