# STATUS - what is actually true

Last measured: **2026-08-27**, by running `cd gates && ./run.sh gate` on this
working tree (Windows, Git Bash, vendored conftest 0.69.0 / OPA 1.19.1). Every
number below came out of that run, recomputed from its output rather than
carried forward from the previous measurement. Nothing here is a projection.

## Built and measured

| Fact | Value | How it was measured |
|---|---|---|
| Gate result | `GATE GREEN`, exit 0 | `./run.sh gate` |
| Same gate in CI | 5 of the 6 gate steps had a job until 2026-08-27; all 5 green, run `33016125195`, 2026-08-26 | GitHub Actions, Ubuntu runner |
| `coverage` job in CI | added 2026-08-27; not yet observed green on a runner | `.github/workflows/gate.yml` |
| Rego unit tests | 66 / 66 pass | `opa test policy tests` |
| Conforming fixtures accepted | 9 per-file + 4 combined sets | `./run.sh conforming` |
| Negative controls refused | 18 / 18 (14 per-file + 4 combined sets) | `./run.sh violations` |
| Rule IDs with a refusing fixture | 9 / 9 | `./run.sh coverage`, local. The fixtures themselves are refused in CI by the `violations` job; the assertion that every ID has one got its own CI job on 2026-08-27 and has not yet run on a runner |
| Deny clauses load-bearing for a refusing fixture | 15 / 15 | `./run.sh coverage`, clause pass — deleting any one clause must reduce some fixture's deny count |
| Findings in vendored historical config | **13** (4 per-file + 9 combined) | `./run.sh historical`, exact-count assertion |
| Vendored files provenance-verified | 22 / 22 blob SHAs, and the tree holds exactly that set | `./run.sh verify-provenance` |

## Rule families

| Family | Rule IDs | Deny clauses | Negative control |
|---|---|---|---|
| security | 4 - SEC-001, SEC-002, SEC-002-DRIFT, SEC-003 | 7 | refusing fixture for each ID (SEC-003 in combined mode), plus refusing unit tests |
| observability | 2 - OBS-001, OBS-002 | 4 | refusing fixture for each ID (module form and bare-resource form) |
| finops | 3 - FIN-001 (combined mode), FIN-002, FIN-003 | 4 | FIN-001: 3 refusing directory sets. FIN-002: 1 refusing fixture (`fixtures/violations/perfile/fin-SYNTHETIC-infracost-per-az-nat.json`) plus refusing unit tests. FIN-003: 1 refusing fixture (`fin-SYNTHETIC-infracost-broken-module-load.json`), which trips both clauses at once, plus unit tests asserting each clause fires alone |

Every rule ID now has a negative control asserted by `./run.sh violations`, and
the asymmetry that used to sit here is gone. FIN-002's over-budget fixture lived
in `gates/fixtures/infracost/`, which no `run.sh` glob covered, so the repo's
headline FIN-002 refusal was asserted only by unit tests. It was moved into the
violations glob on 2026-08-24: a refusing fixture CI never runs is not a
negative control.

## What adversarial review changed on 2026-08-24

Two independent skeptic passes returned PARTIALLY_REFUTED (methodology) and
REFUTED (documentation). Their findings were fixed rather than argued with:

- **A tool error was being counted as a refusal.** `conftest` exits 1 both when
  a policy refuses an input and when it cannot read one, and the violations loop
  checked only the exit code - so an empty directory, or a file with no known
  parser, passed as a negative control. The loop now counts actual deny messages
  and fails loudly on a tool error. Proven by mutation: an empty combined
  directory and a stray `.txt` both now fail the target; the clean tree stays
  green.
- **The vacuity guard was total-only.** One `n > 0` across both classes meant
  deleting every combined fixture - the only negative controls FIN-001 and
  SEC-003 have - still passed. Guards are now per class.
- **One SEC-001 clause had no fixture in the CI loop.** SEC-001 is four deny
  bodies; the `aws_security_group_rule` + `::/0` clause was covered only by a
  unit test, so deleting it would not have turned the gate red. A fixture was
  added (17th control) and `./run.sh coverage` now asserts every declared rule
  ID is emitted by some refusing fixture.
- **`|| true` had crept back into `run.sh`'s `combined` target** with no
  preceding count assertion. Removed; the display re-runs now tolerate a
  non-zero exit only after a count has proved it came from real deny messages.
- **README claimed CI operation that has never happened** (see below).

### Known limit — CLOSED 2026-08-27

`./run.sh coverage` was **ID-level, not clause-level**: a rule with several deny
bodies sharing one ID counted as covered when any one of them fired, so the
SEC-001 gap above could recur in a different clause without turning the gate
red. It now runs a second pass, `t_clause_coverage`, asserting the property
directly:

> deleting any one deny clause must reduce the deny count of at least one
> fixture under `fixtures/violations/`

A clause whose removal changes nothing is a clause no negative control
exercises. **All 15 clauses pass**, each reported with the fixture that proves
it. The check needed no change to any message, fixture or unit test — the
message-tagging approach it replaces would have rewritten the expected text of
all 18 fixtures, a large share of the 66 unit tests, and the README demo line,
in order to make the gate legible to itself.

Proven by two mutations, both run:

- **It catches the recorded gap.** Removing
  `fixtures/violations/perfile/sec-sg-rule-open-ingress-v6.tf` — the fixture
  that proves SEC-001's `aws_security_group_rule` + `::/0` body — leaves the
  ID-level pass reporting *"every declared rule ID is exercised by a refusing
  fixture"*, a full pass, because SEC-001 still fires from three other
  fixtures. The clause pass names `policy/security.rego:45` and exits 1. That
  is exactly the 2026-08-24 defect, which was found by hand.
- **It catches a dead clause.** Appending a deny body that no fixture can
  match turns the target red naming its line, 1 of 16; the clean tree is green
  at 15 of 15.

Cost: the `gate` chain went from ~6s to ~14s on Windows. Nothing is
short-circuited or sampled, locally or in CI, and the target says so in its own
output.

Three limits, stated rather than discovered later:

1. **Only `fixtures/violations/` counts as a negative control.** A clause
   load-bearing solely for a finding in `fixtures/historical/` reads UNCOVERED
   by design — a historical finding is evidence of what was shipped, not a
   control over what may ship. The check prints that definition alongside any
   failure. No clause is currently in that position, so this branch is a
   stated rule, not an exercised path.
2. **Two clauses rendering identical message text for the same fixture** would
   collapse under Rego's set semantics and read as uncovered. That is an
   over-strict false red — the safe direction — and it would point at a real
   smell.
3. It proves each clause is load-bearing for *some* fixture, **not** that the
   fixture exercises it for the right reason.

## What running Infracost for the first time changed on 2026-08-26

Two defects, both found by running the tool rather than by reading the code.

1. **A failed Infracost parse is silent, costs $0.00, and exits 0.** The first
   `infracost breakdown` against the evidence tree could not load
   `../modules/iam/*`, priced nothing, printed "No cloud resources were
   detected", reported `totalMonthlyCost` `"0"` — and returned exit status 0.
   FIN-002 compares that number against a ceiling, and 0 is under every ceiling,
   so committing that file would have produced a permanently green cost gate
   reading a broken parse. **FIN-003** now refuses a breakdown carrying
   `metadata.errors` or reporting zero detected resources. This is the second
   instance of a defect class already in the ledger: a tool reporting "I could
   not evaluate this" through the same channel it uses for "this is fine".

2. **`verify-provenance` was blind to added files.** That same run wrote a 22MB,
   822-file `.infracost/` module cache *into* `fixtures/historical/terraform/`.
   All 22 blob SHAs still matched and the check still printed "22 files
   verified", because it iterates the ledger, not the tree. The contamination
   was caught only by the historical finding count moving 13 → 100 — and only by
   luck, because the downloaded third-party modules happened to trip OBS-001. An
   addition tripping no rule would have been committed as evidence. The check now
   asserts the tree contains **exactly** the recorded set; a mutation test
   confirms it fails on one added file and passes when clean.

   The cache was deleted and the tree restored; `git diff` over the 22 files was
   empty throughout, so no vendored byte was ever altered.

3. **CI was red for a day and nobody could have told from the docs.** The first
   push, 2026-08-25, produced run `32802416866`, which failed in 13 seconds:
   `gates/run.sh` was committed with mode `100644`, because `core.filemode=false`
   on the Windows box means git never records the on-disk executable bit. Job one
   died on `Permission denied` (exit 126) and the four policy-evaluating jobs
   were **skipped**, since they `needs:` it — so a full day of "the gate works"
   rested on local runs only. Fixed by writing the mode into the index with
   `git update-index --chmod=+x`; run `33016125195` on 2026-08-26 is green across
   all five jobs. Note for anyone repeating this on Windows: `chmod +x` alone is
   a no-op under `core.filemode=false`.

## What re-deriving the docs from the tree found on 2026-08-27

**A gate step had no CI job, and four documents said otherwise.** `t_gate()` has
called `t_coverage` since 2026-08-24, but `.github/workflows/gate.yml` defined
five jobs and none of them ran it. So the assertion "every declared rule ID is
emitted by some refusing fixture" existed only on a developer's machine: a rule
shipped with no negative control would have merged green, because the other
fixtures were still refused and no job checked the set. That is precisely the
defect this repo exists to correct — a check that cannot fail the build is not
a check — recurring inside the gate's own CI. It is the third instance of the
class already in this file, after the `|| true` Checkov steps and FIN-002's
fixture sitting outside every `run.sh` glob.

It was not found by reading the workflow. It was found by refusing to patch the
lines a handoff note named, and re-deriving every job-count claim in the repo
from the tree instead. That sweep turned up four claim sites, not the one:

| Where | Said | Actually |
|---|---|---|
| `.github/workflows/gate.yml` header | "one job per target" | never true — `combined`, `parse`, `demo`, `tools` have no job, and `coverage` had none either |
| `CLAUDE.md` layout table | "one job per run.sh target" | same wording, same error |
| `README.md` "Run it" | "The same five are DEFINED as separate jobs"; target list omitted `coverage` entirely | six gate steps, six jobs |
| `README.md` `./run.sh gate` comment | "provenance, unit, conforming, violations, self-audit" | `coverage` missing between violations and the self-audit |

Widening the same sweep to every *number* in README found three more, two of
them self-contradictions the file had been carrying openly:

| Where | Said | Re-derived from the tree |
|---|---|---|
| `README.md` negative controls | "16 such fixtures - 12 single-file and 4 directory sets" | 18 - 14 single-file, 4 directory sets. README's own CI paragraph said 18 eleven lines later |
| `README.md` demo transcript | quoted verbatim as "13 tests, 12 passed" | re-running `./run.sh demo` prints "15 tests, 14 passed" - FIN-003 added two clauses on 2026-08-26 and the quoted block was never re-run |
| `README.md` FIN-002 | "no real `infracost breakdown` has ever run against this repo (no API key)" | one did, on 2026-08-26, authenticated; the output was deliberately not committed. This file has recorded that since the same day |

A verbatim transcript is a claim with an expiry date: it is the one kind of
documentation that goes stale without a single word of it being edited.

### The vendored bytes were re-checked against the ref itself, not just the ledger

`PROVENANCE.md` is careful about what the offline check proves: "the 22 files
are **unmodified since vendoring**... It does NOT re-check them against the
upstream ref... The equality with the ref was established once, at vendoring
time, on 2026-08-24." That is the stronger claim the repo rests on and the one
nothing had re-tested.

On 2026-08-27 it was re-tested. An archived local clone of the source subtree
carries its own `.git` and can reach ref `95df6efd8be92dc589e2cbd0124c79b78922dade`
offline, so every ledger row was compared against `git ls-tree` at that ref:
**22 match, 0 differ, 0 absent.** Ref-equality now holds as of two dates, not
one, and it was established by comparison rather than by trusting the earlier
comparison.

`PROVENANCE.md`'s sentence is therefore understated. It has deliberately **not**
been edited: it lives under `gates/fixtures/historical/`, and hard rule 1 in
`CLAUDE.md` forbids editing or adding anything there without qualification.
Updating the ledger's own prose is the author's call, not an agent's — flagged
here rather than done.

All four are corrected in the same commit as the job itself. The past-tense
records were deliberately **not** rewritten: run `33016125195` really did have
five jobs, and run `32802416866` really did skip four, so those numbers stand
as written. Only the present-tense structural claims moved to six.

## The 13 historical findings

Against `gates/fixtures/historical/`, vendored from
the platform-infrastructure subtree of my local monorepo (name withheld) at provenance SHA
`95df6efd8be92dc589e2cbd0124c79b78922dade`:

- 8 x FIN-001 - combined over the `terraform/` root module: `ecr.tf`,
  `elasticache.tf` (3), `rds.tf`, `secrets.tf` (3)
- 1 x OBS-001 - `terraform/vpc.tf`, per-file
- 3 x SEC-002 - `kube/base/egress-common.yaml`, per-file
- 1 x SEC-003 - combined over the `kube/` tree, both NetworkPolicy files

All 8 FIN-001 messages now name `App`, and only `App`, which is the tag that is
genuinely absent everywhere. Until 2026-08-24 they also named `Environment`, and
that was a false finding: `provider "aws"` in `terraform/versions.tf` supplies it
through `default_tags`, which in Terraform applies to the entire root module. The
rule was per-file and could not see it. See the correction log at the end of this
file, and the now-closed ruling OQ-1.

## Not yet - do not claim these

- **The gate has not yet refused anything in a pull request.** Run
  `33016125195` proves the rules execute and refuse in CI, but it ran on a push
  to `master` where every fixture was already in its expected state. The claim
  "here is the gate blocking a violation from merging" needs a PR whose check
  goes red on a deliberate violation, and no such PR exists yet.
- **Infracost: path taken is local-run-committed-output** (commit the JSON, gate
  the committed file - no API call in CI). **The committed fixtures are still
  hand-authored and still not measurements.** Both keep their `SYNTHETIC-`
  filename element and `_synthetic` marker key, and any dollar figure this repo
  ships is illustrative. That is now a *decision*, not a limitation: on
  2026-08-26 infracost v0.10.45 was installed and authenticated, and real
  breakdowns were run. The output was deliberately **not** committed, so nothing
  below is in the repo.

  What those runs established, recorded here because it bears on claims made
  above:

  1. **The schema FIN-002 reads is correct.** `projects[].name` and
     `projects[].breakdown.totalMonthlyCost` (a decimal *string*) were observed
     in real v0.10.45 output. Note this is version-bound: infracost v2.x moved to
     `projects[].project_name` and `summary.total_monthly_cost`, against which
     FIN-002 would match nothing and silently approve every cost.
  2. **`budget.json`'s ceilings no longer mean what they say.** dev = 250 and
     prod = 900 were derived from the synthetic NAT-only figures (221.33 /
     287.03). Measured reality, from a tree with the missing modules restored:
     dev single-NAT **594.42**, dev per-AZ-NAT **660.12**, prod **853.40**. The
     dev ceiling is therefore ~2.4x below its own baseline. Adopting real
     fixtures requires re-deriving it (any value between 594.42 and 660.12
     preserves the intent: single-NAT passes, per-AZ refuses). Prod's 900, long
     labelled a placeholder, happens to sit 5.5% above measured prod.
  3. **The evidence tree cannot reproduce those numbers.** `terraform/iam.tf`
     sources `../modules/iam/{builder,pod,provisioner}` — nine files that exist
     at ref `95df6ef` but sit one directory above the vendored subtree and were
     never vendored. Without them infracost prices nothing.
  4. **A failed parse is silent and exits 0**, which is what produced FIN-003
     below. This is the finding that justified the day.

  `gates/fixtures/infracost/README.md` holds the replacement procedure.

### Not claimable, full stop

Live `terraform plan` / `apply` gating. Enforcement of anything running.
Flow-log aggregation or egress-GB-per-app reporting (not built). Cluster-side
request interception (not built; this is a CI gate over files). Any real
Infracost measurement.

## Open rulings, defaulted by the author

- **OQ-1 - tag semantics. CLOSED 2026-08-24.** Does
  `provider "aws" { default_tags }` satisfy FIN-001? **Yes, across the whole
  root module** - which is what Terraform actually does. `default_tags` is a
  property of the provider configuration; which `.tf` file a resource is written
  in is a source-layout choice with no semantic meaning. The earlier "yes, but
  only within the same input file" default restated a tool limit as a policy,
  and made the gate emit findings that were not true. Resolved by moving FIN-001
  to `--combine` mode over `terraform/`, where the provider fact is visible. The
  credit is computed as the union of every `default_tags` block in the set,
  never a pinned key list - a pinned list would credit `Environment` in a repo
  that never declares it, and would make the same-file/other-file distinction
  untestable.
- **OQ-3 - repository shape.** **Defaulted to: keep the directory named
  `network-as-code`, with the gate living in a `gates/` subdirectory.** The
  workflow therefore sets `defaults.run.working-directory: gates` and lives at
  the repo root, where GitHub requires it.

## Integration changes made on 2026-08-24 (integrator)

1. `run.sh verify-provenance` did `cd "$HIST"` and never returned, so every
   later target ran from `fixtures/historical/` and could not find
   `../.tools/opa.exe`. `./run.sh gate` failed at the first tool call on
   Windows, and would have masked itself in CI where the tools are on PATH.
   Fixed by prefixing the paths instead of changing directory.
2. Unit tests asserted on the **global** `deny` set. All families are package
   `main`, so FIN-001 fired on the sec/obs mocks: 7 tests were red, and several
   green ones were vacuous (`count(deny) > 0` would have passed with SEC-001
   deleted). Assertions are now scoped per family (`sec_only` / `obs_only`).
3. Four conforming fixtures were refused by FIN-001 for missing allocation tags.
   A conforming fixture must conform to every family; tags added.
4. The SEC-001 clause for `aws_security_group_rule` + `ipv6_cidr_blocks` had no
   refusing test. Added one, and confirmed by mutation: deleting the clause
   turns exactly that test red (46/47).
5. `HISTORICAL_EXPECTED` was a scaffold placeholder of 5; the measured count is
   13. Set to 13 with the composition recorded in `run.sh` and above. No rule
   was tuned to hit a number.

## Three defects found and fixed on 2026-08-24 (second pass)

1. **FIN-001 evaluated a provider-wide fact per file, so it reported findings
   that were false.** `default_tags` applies to every resource in the Terraform
   root module; the rule credited it only when the provider block appeared in
   the same parsed file, and conftest evaluates one file per policy evaluation.
   Against the vendored config that produced 8 messages all claiming
   `Environment` was missing, when `terraform/versions.tf` declares it. FIN-001
   moved to `gates/policy/combined/finops_combined.rego` and now runs under
   `--combine` over the terraform root module, crediting the union of every
   `default_tags` block declared by any file in the set. The per-file clause was
   deleted outright rather than left as a weakened duplicate - two rules under
   one ID is its own lie. Its fixtures became directory sets under
   `gates/fixtures/conforming/combined/` and `.../violations/combined/`,
   including the case that reproduces the historical layout (provider in one
   file, resource in another) and must PASS. **The count did not move: still 8,
   because `App` is genuinely absent on all 8 resources.** The messages are what
   changed. Verified by mutation: disabling the cross-file union turns that
   conforming set red, and 6 unit tests with it.
2. **FIN-002 had no negative control in CI.** Its over-budget fixture lived in
   `gates/fixtures/infracost/`, which neither the conforming nor the violations
   glob covered - so the repo's headline refusal was asserted only by unit
   tests, in a repo whose stated methodology is that every rule ships a fixture
   CI must refuse. Both breakdown JSONs moved into the globbed directories, the
   `SYNTHETIC-` filename element and `_synthetic` marker key intact.
   `gates/fixtures/infracost/` remains as the documented replacement procedure.
3. **`policy/budget.json` was documented as authoritative but was never read.**
   The enforced numbers lived in `fin002_embedded_budget` and were hand-synced,
   and the previous `data[env]` lookup could never have resolved at all: a
   dynamic `data` reference inside package `main` is a compile error
   (`rego_recursion_error: rule data.main.deny is recursive`), not a runtime
   miss. `run.sh` now passes `--data policy` on every conftest invocation and
   the rule reads static `data.dev` / `data.prod`. Verified by lowering the dev
   ceiling in `budget.json` to 200.0 and watching the 221.33 conforming fixture
   get refused, then restoring it. The embedded map survives as a fallback for a
   bare `conftest test` with no `--data`, but is no longer trusted:
   `test_fin002_embedded_budget_matches_budget_json` asserts it equals
   `budget.json` value-for-value and goes red on drift. Ceilings are stored as
   floats and rendered through `fin002_usd`, because sprintf's `%f` verb refuses
   an int64 - `250` used to render inside the message as `$%!f(int64=250)`.

**The "known stale doc" note that used to sit here was itself the stale claim.
Corrected 2026-08-27.** From 2026-08-24 this file carried a note saying
`gates/docs/parse-shape.md` "still lists FIN-001 under `policy/` per-file rules
and says `policy/combined/` holds 'SEC-003 only'". Neither was true. That
document has read `policy/combined/ - cross-file rules (SEC-003, and FIN-001)`
since its only commit (`4319ab2`), and carries a paragraph arguing why FIN-001
belongs in combined mode. The string "SEC-003 only" appeared nowhere in the repo
except inside the note making the accusation. A carried-forward claim about a
document survived nine days without anyone opening the document.

Re-deriving parse-shape.md against the tree instead of patching the two lines
the note named found two real errors, neither of them the ones alleged:

1. **Its "cosmetic quirk" about `>` was wrong, in the direction that ships a
   dead rule.** It called the `>` in `conftest parse` output "HTML-escaped"
   and instructed rule authors to "compare with the escaped form". That is JSON
   serialization, not HTML, and it is a rendering artifact - Rego sees the
   ordinary `~> 5.0`. Anyone who followed the instruction literally and wrote
   `&gt;` would have shipped a clause that could never fire. Verified by running
   three comparisons against `terraform/vpc.tf`: plain form, `>` literal,
   and `contains(v, ">")` all match.
2. **FIN-003 was missing from the per-file rule set**, having shipped on
   2026-08-26 without the contract document being updated.

The exit-code note was also incomplete in a way that matters: it recorded that
`conftest test` exits 1 on a refusal without recording that it exits 1 on an
unreadable input too, which is the entire reason `run.sh` counts deny messages
rather than reading `$?`. Now stated in both places.
