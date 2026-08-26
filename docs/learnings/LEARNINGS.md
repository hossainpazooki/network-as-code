# Learnings ledger

Pointers only. Evidence lives in the dated entries. Entries are immutable: a
wrong entry is superseded by a new dated entry carrying a `kills:` reference,
never edited in place.

| Date | Entry | Status | One-line |
|---|---|---|---|
| 2026-08-25 | [conftest --combine changes the input shape](2026-08-25-conftest-combine-changes-input-shape.md) | verified | Per-file input is one document; `--combine` makes it a list of `{path, contents}`, so a rule works in one mode or the other, never both. |
| 2026-08-25 | [conftest's exit code cannot distinguish an error from a refusal](2026-08-25-conftest-exit-code-cannot-distinguish-error-from-refusal.md) | verified | Exit 1 means both "policy refused" and "could not read the input", so an exit-code-only negative control counts an empty directory as passing. |
| 2026-08-25 | [Terraform default_tags is provider-wide](2026-08-25-terraform-default-tags-is-provider-wide.md) | refuted-assumption | A per-file tag rule cannot see the provider block, so it reports tags missing that are actually applied at provision time. |
| 2026-08-25 | [A dynamic data[var] reference is a rego_recursion_error](2026-08-25-dynamic-data-reference-is-a-rego-recursion-error.md) | verified | In `package main`, `data[env]` will not compile; only static paths like `data.dev` resolve. |
| 2026-08-25 | [opa test and conftest load data differently](2026-08-25-opa-test-and-conftest-load-data-differently.md) | verified | `opa test` auto-loads JSON under the policy dir; conftest needs an explicit relative `--data` root or the file is invisible. |
| 2026-08-26 | [A failed Infracost module load costs $0.00 and exits 0](2026-08-26-infracost-failed-module-load-costs-zero-and-exits-0.md) | verified | A broken parse emits `totalMonthlyCost` "0" and returns exit 0, so a cost ceiling reading it approves everything; FIN-003 exists because of this. |
| 2026-08-26 | [Infracost v2 renamed the breakdown schema](2026-08-26-infracost-v2-renamed-the-breakdown-schema.md) | verified | v2 moved to `project_name` / `summary.total_monthly_cost`, against which a v0.10-shaped rule matches nothing and silently passes. |
| 2026-08-26 | [A ledger-driven integrity check is blind to additions](2026-08-26-a-ledger-driven-integrity-check-is-blind-to-additions.md) | verified | Hashing each recorded path proves nothing about files added alongside them; 822 unrecorded files passed provenance clean. |
