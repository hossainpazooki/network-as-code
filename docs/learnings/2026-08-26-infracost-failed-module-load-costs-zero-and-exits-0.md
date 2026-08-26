# A failed Infracost module load costs $0.00 and exits 0

ts: 2026-08-26T21:30:39Z
commit: (none - this change was uncommitted at capture time; repo HEAD bbcd6a3 predates it)
session: https://claude.ai/code/session_01A1FzkjBaAADiWxTmdjrBGg
status: verified
fact: `infracost breakdown` exits 0 when it cannot load a project's modules. It prices nothing, prints "No cloud resources were detected", and still emits a well-formed breakdown JSON whose `totalMonthlyCost` is the string "0" over an empty `resources` array. A cost-ceiling rule reading that file compares 0 against the budget and ACCEPTS it, permanently and silently. The only in-band signals are `projects[].metadata.errors` (a `[]*ProjectDiag` of `{code, message, data, isError}`, absent on success, code 102 = diagModuleEvaluationFailure) and `projects[].summary.totalDetectedResources` (0 on failure).
basis: on 2026-08-26, `infracost breakdown --path . --terraform-var-file envs/dev.tfvars --project-name dev` run with infracost v0.10.45 inside gates/fixtures/historical/terraform printed "Error loading Terraform modules: could not load modules for path . open ../modules/iam/pod: no such file or directory" and "OVERALL TOTAL $0.00", then returned exit status 0, captured explicitly as `EXIT CODE: 0`. The identical command against a scratch copy with the nine missing `modules/iam/**` files restored from ref 95df6ef returned `totalMonthlyCost` "594.416" over 12 costed resources with `metadata.errors` absent. Both runs were read-only with respect to the repo.
re-verify: cd gates && ../.tools/conftest.exe test fixtures/violations/perfile/fin-SYNTHETIC-infracost-broken-module-load.json --policy policy --data policy --all-namespaces 2>&1 | grep -c "FIN-003"

Re-observing the infracost behaviour itself requires infracost installed and
authenticated, so the line above instead re-verifies the guard built from it:
FIN-003 refuses the reconstructed broken-parse fixture on both clauses, printing
2. This is the second instance of the class recorded in
[[2026-08-25-conftest-exit-code-cannot-distinguish-error-from-refusal]] - a tool
reporting "I could not evaluate this" down the same channel it uses for "this is
fine". Related: [[2026-08-26-infracost-v2-renamed-the-breakdown-schema]].
