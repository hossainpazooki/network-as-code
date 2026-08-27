# Handoff — network-as-code ship: the claim closed, FIN-002 measured, exception spent

2026-08-27. Newest commit this brief describes: `ae2a05c` (merge of PR #2 into
`master`). Pick-up measures drift from there. Written for `/rigor:pickup`:
every claim below carries the read-only command that re-checks it. Run them
from the repo root on `master` after `git pull`.

## Current state

**built** — The claim's verb is *blocks*. PR #1 (`865de9d`, run
`33090175858`): `conforming` failed with the SEC-001 line naming the added
file; `verify-provenance` and `unit` passed (they run first and never read
that directory); `violations`, `coverage`, `historical` skipped; API merge
state `BLOCKED`, `mergeable: MERGEABLE`. The PR stays open, unmerged, on
purpose. It now also reads *behind* because `master` moved after it — the
state above is as of that run, and the log is the durable record.
re-verify: `gh api repos/hossainpazooki/network-as-code/actions/runs/33090175858/jobs --jq '.jobs[] | "\(.name) \(.conclusion)"' && gh pr view 1 --json state,mergeStateStatus`

**built** — Branch protection on `master`: exactly the six gate jobs
required, `enforce_admins: true` (no bypass for the owner), strict
up-to-date, no force pushes, no deletions. Consequence: every commit to
`master` travels by PR.
re-verify: `gh api repos/hossainpazooki/network-as-code/branches/master/protection --jq '{contexts: .required_status_checks.contexts, admins: .enforce_admins.enabled, strict: .required_status_checks.strict}'`

**built** — The vendored evidence is a complete Terraform root module: 31
files (22 + the nine `modules/iam/**` files `terraform/iam.tf` sources),
blob-SHA pinned, tree-exactness enforced. Commit `888e7b5`.
re-verify: `cd gates && ./run.sh verify-provenance` → `31 files verified against PROVENANCE.md, and the tree contains exactly that set.`

**built** — Historical self-audit asserts **15** (13 until `888e7b5`);
composition 4 per-file + 1 kube-combined + 10 terraform-combined, the two
new findings being `aws_iam_role.builder` / `.provisioner` missing `App`.
re-verify: `cd gates && ./run.sh historical 2>&1 | grep -E '^total'` → `total : 15 (expected 15)`

**built** — FIN-002 reads measured Infracost breakdowns (v0.10.45, HCL
mode, 2026-08-27): dev single-NAT 594.416 (conforming), dev per-AZ 660.116
(violation), prod 853.404 (conforming), each with a `_provenance` block.
Ceilings derived: dev 625.0, prod 900.0. Commit `329ea10`.
re-verify: `python -c "import json;[print(f, json.load(open(f))['_provenance']['totalMonthlyCost']) for f in ['gates/fixtures/conforming/perfile/fin-infracost-dev-single-nat.json','gates/fixtures/violations/perfile/fin-infracost-dev-per-az-nat.json','gates/fixtures/conforming/perfile/fin-infracost-prod.json']]" && grep -E '"monthly_usd_max"' gates/policy/budget.json`

**built** — FIN-004 refuses a breakdown with no project in the v0.10 shape
FIN-002 reads; its negative control is a hand-authored v2-shaped file refused
by FIN-004 alone. Commit `58b0343`.
re-verify: `cd gates && ../.tools/conftest.exe test fixtures/violations/perfile/fin-SYNTHETIC-infracost-v2-schema.json --policy policy --data policy --all-namespaces -o json 2>/dev/null | python -c "import json,sys; print([f['msg'][:8] for r in json.load(sys.stdin) for f in r['failures']])"` → `['FIN-004:']` (Linux: `conftest` on PATH)

**built** — Gate green on this tree, locally and in CI: 74/74 unit, 19
negative controls (15 per-file + 4 combined), 10/10 rule IDs, 16/16 deny
clauses load-bearing, 15/15 historical, 31/31 provenance. CI run
`33089563447` (six jobs, over `19ec327`); run `33091623544` is the
post-merge run over `ae2a05c` and was in progress when this brief was
written — pick-up reads its conclusion, not this sentence.
re-verify: `cd gates && ./run.sh gate 2>&1 | grep -E 'PASS: |negative controls|deny clauses|files verified|^total|GATE GREEN'` and `gh run view 33091623544 --json conclusion`

**built** — README rewritten for a technical skimmer (Terraform
foregrounded, five mermaid diagrams, PR #1 cited with the narrow sentence,
AI-assistance two-liner). Commit `b04bb0c`.
re-verify: `git show origin/master:README.md | grep -c '^```mermaid'` → `5`; `git show origin/master:README.md | grep -n 'See it block a merge'`

**planned** — Nothing is in progress. The only open item is the Infracost
GitHub App decision (Open / next).

## Locked decisions

- **F1 — single red PR, and the narrow sentence.** *"The violating file
  turned exactly the job that reads it red."* Never "the other jobs stayed
  green": two ran before it and never read the file, three were skipped.
  Reason: only one job reads `fixtures/conforming/`
  (`grep -n 'fixtures/conforming' gates/run.sh` → inside `t_conforming()`
  only). Ruled by the author 2026-08-27 (amendment A2 to the plan).
- **F2 — ceilings dev 625.0 / prod 900.0.** Reason: 625 sits near the
  midpoint of (594.416, 660.116) so neither verdict is knife-edge; 900 is
  measured 853.404 + 5.5%, now derived rather than a placeholder. Recorded in
  `gates/policy/budget.json` `_comment` and `docs/handoff/2026-08-27-infracost-adoption-plan.md` §3.
- **F3 — the nine module files live under `fixtures/historical/`** (ledger
  22 → 31), as the one sanctioned exception to hard rule 1, ruled and
  recorded with the nine blob SHAs at `9b68fc4` *before* the files landed.
  Reason: completing an incomplete image of one root module at one ref; the
  alternative (a sibling tree) splits provenance across two ledgers and still
  leaves `iam.tf`'s `../modules/iam/*` dangling. `STATUS.md` §"The one
  sanctioned exception".
- **F4 — `terraform/` + `modules/` is ONE `--combine` set, and the nine
  files are in the per-file loop too.** Reason: a child module with no
  provider block inherits the root provider's `default_tags`; evaluating
  `modules/` alone emits a false `Environment` finding (proven; ledger entry
  `2026-08-27-a-directory-glob-is-a-policy-decision.md`, whose `re-verify:`
  line shows it). Ruled 2026-08-27.
- **FIN-004 is its own rule ID, not a third FIN-003 clause.** Reason:
  different cause (tool version, not tool error), different fix, own
  negative control. Deviation from the adoption plan, stated in that plan's
  header.
- **Claim ceiling for cost:** *"cost-delta gating demonstrated on pinned
  point-in-time estimates."* Never "cost controlled", never "live". Reason:
  the numbers are one dated run's prices; CI evaluates bytes.
- **Dates come from artifacts, not briefs.** The seed said 2026-08-28; the
  clock, GitHub and Infracost's `timeGenerated` said 2026-08-27; 14
  occurrences were corrected before commit. Ledger entry
  `2026-08-27-the-artifact-carries-the-date-not-the-brief.md`.

## Reuse map

- `gates/run.sh` — every target; `deny_count` (never trust `$?`),
  `clause_fixture_counts` + `t_clause_coverage` (mutation-derived clause
  coverage), `t_verify_provenance` (ledger + tree-exactness).
- `gates/policy/finops.rego` — FIN-002/003/004 with the `data.<env>` static
  lookup pattern and the `fin002_usd` int64 workaround; `finops_combined.rego`
  for the `default_tags` union credit.
- `gates/fixtures/infracost/README.md` — the regeneration procedure and the
  generation/evaluation split table. Regenerate against a *copy*, never inside
  `fixtures/historical/`.
- Per-commit snapshot technique for green-at-every-commit sequences with
  `enforce_admins` on: assemble each state from `git archive HEAD` in scratch
  and run the gate there before emitting commit commands (used for `888e7b5`
  → `329ea10` → `58b0343`).
- Mermaid parse validator: `mermaid.parse()` under jsdom (mermaid 11.17.2),
  self-tested against a deliberately broken block. Lives in the session
  scratchpad, not the repo — rebuild takes one `npm install mermaid jsdom`.
- `docs/learnings/` — 15 entries, each with an executable read-only
  `re-verify:` line.

## Invariants

- **Hard rule 1, and the exception is spent.** Never edit *or add* anything
  under `gates/fixtures/historical/`. `verify-provenance` fails on any
  modified or unrecorded file. A second addition, for any reason, is a
  violation — the exception was ruled at `9b68fc4`, exercised at `888e7b5`,
  and `CLAUDE.md` says it is not a precedent.
- **No `|| true`, no `continue-on-error`, anywhere.** Count deny messages;
  never read an exit code as a verdict (conftest exits 1 on both refusal and
  unreadable input; infracost exits 0 on both priced and unpriced; `grep -c`
  exits 1 on a zero count — ledger entries for each).
- **Every guard ships with a mutation proof**, red and clean both quoted.
- **`HISTORICAL_EXPECTED` moves only with STATUS in the same commit**, every
  delta adjudicated as a true finding first (the FIN-001 false-finding episode
  is the standard).
- **Zero credentials at evaluation time.** Infracost generation is local,
  once, with an Infracost API key and no AWS credential; CI never calls it.
- **`enforce_admins` is on.** Direct pushes to `master` are rejected; every
  change goes by PR through the six checks. Breaking this to "save time"
  removes the evidence PR #1 rests on.
- **STATUS.md is the claim ceiling.** Nothing is cited outside the repo until
  it has a dated row there, and no row is written until the thing has run.
- **README quotes a verbatim demo transcript** (`16 tests, 15 passed`); it
  goes stale silently whenever a deny clause is added. Re-run `./run.sh demo`
  and compare on every rule change.

## Open / next

1. **`git pull` on the local clone** — local `master` is at `19ec327`; the
   remote is at `ae2a05c`. Until then the working-tree README is the old one.
2. **The Infracost GitHub App.** It attached itself to the repository when
   Infracost Cloud was authenticated on 2026-08-26 and reports an `Infracost`
   check on PRs (not required; cannot affect merging). It is an external
   credentialed reader of a repo whose claim is "no Infracost call in CI".
   Recorded in `STATUS.md`; remove (GitHub → Settings → Integrations) or keep
   and say so — the author's call. Blocker: none.
3. **Read the post-merge run.** `33091623544` over `ae2a05c` was in progress
   at write time. If it is anything but six successes, that is the first
   thing to explain.
4. Nothing else is queued. The repo's stated claim is closed; further work is
   new scope, not this handoff's.
