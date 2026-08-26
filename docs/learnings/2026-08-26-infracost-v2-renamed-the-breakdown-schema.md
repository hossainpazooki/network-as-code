# Infracost v2 renamed the breakdown schema, so a v0.10 rule silently matches nothing

ts: 2026-08-26T21:30:56Z
commit: (none - this change was uncommitted at capture time; repo HEAD bbcd6a3 predates it)
session: https://claude.ai/code/session_01A1FzkjBaAADiWxTmdjrBGg
status: verified
fact: Infracost moved repositories (`infracost/infracost` -> `infracost/cli`) at v2, and the JSON output was renamed from camelCase to snake_case with a different nesting. v0.10.x emits `projects[].name` and `projects[].breakdown.totalMonthlyCost` (a decimal STRING); v2.x emits `projects[].project_name` and `summary.total_monthly_cost`. A Rego rule written against the v0.10 paths does not error against v2 output - the reference is simply undefined, the deny body never binds, and the rule approves every input. The v0.10.45 CLI prints an update banner pointing at v2, so the upgrade is offered as routine when it is in fact schema-breaking.
basis: struct tags read from source on 2026-08-26. `infracost/infracost` internal/schema/project.go line 63 `Name string json:"name"`, line 67 `Breakdown *Breakdown json:"breakdown"`, line 269 `TotalMonthlyCost *decimal.Decimal json:"totalMonthlyCost"`. `infracost/cli` internal/format/json.go line 62 `ProjectName string json:"project_name"`, line 47 `TotalMonthlyCost *rat.Rat json:"total_monthly_cost"`. The v0.10 side was then confirmed against real output: a live v0.10.45 breakdown returned `name` = 'dev' and `breakdown.totalMonthlyCost` = '594.416' as a string. The old repo is not archived (checked via the API) and v0.10.45 was published 2026-07-03.
re-verify: cd gates && grep -c "breakdown.totalMonthlyCost\|project.breakdown" policy/finops.rego

FIN-002 is therefore version-bound, and the binding is invisible at the call
site: nothing in the policy names an infracost version. `./run.sh tools` pins
conftest and opa but not infracost, because infracost is never invoked by the
gate - only its committed output is read. The pin that matters is on whichever
binary generated that committed JSON. Related:
[[2026-08-26-infracost-failed-module-load-costs-zero-and-exits-0]].
