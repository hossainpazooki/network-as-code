# Handoff — network-as-code gates, first build

**2026-08-25 (UTC; local clock read 2026-08-24 when the docs were written — that
offset explains why STATUS.md says "Last measured 2026-08-24" while the learnings
entries carry `2026-08-25T02:4x:xxZ`. It is not drift.)**

**Newest commit this brief describes: NONE — the repository has zero commits and
no remote.** Everything below is an untracked working tree at
`~/dev/network-as-code`. Pick-up cannot measure drift from a SHA here; measure it
by running `cd gates && ./run.sh gate` and comparing against the numbers in
"Current state". The commit commands that would create the initial history are in
"Open / next" and had not been run as of this brief.

---

## Current state

### Built

| Item | Tag | re-verify |
|---|---|---|
| Whole gate, end to end | built | `cd gates && ./run.sh gate` → ends `=== GATE GREEN ===`, exit 0 |
| 8 rule IDs across 3 families (SEC-001, SEC-002, SEC-002-DRIFT, SEC-003, OBS-001, OBS-002, FIN-001, FIN-002) | built | `grep -rhoE '"[A-Z]{3}-[0-9]{3}(-[A-Z]+)?:' gates/policy \| sort -u` → 8 lines |
| 59 Rego unit tests | built | `cd gates && ../.tools/opa.exe test policy tests` → `PASS: 59/59` |
| 17 negative controls, each asserted refused | built | `cd gates && ./run.sh violations` → `13 per-file + 4 combined = 17 negative controls, all refused.` |
| Rule-ID coverage gate | built | `cd gates && ./run.sh coverage` → `every declared rule ID is exercised by a refusing fixture.` |
| Self-audit against vendored evidence, exact-count asserted | built | `cd gates && ./run.sh historical` → `total : 13 (expected 13)` |
| 22 vendored fixtures pinned by git blob SHA | built | `cd gates && ./run.sh verify-provenance` → `22 files verified against PROVENANCE.md.` |
| Parse-shape contract doc | built | `sed -n '1,10p' gates/docs/parse-shape.md`; regenerate evidence with `cd gates && ./run.sh parse` |
| CI workflow, fail-closed, checksum-verified tools | built (never executed) | `grep -n 'branches' .github/workflows/gate.yml` → `[main, master]`; see "not started" below |
| 30-second demo | built | `cd gates && ./run.sh demo` → refuses `netpol-wide-ipblock.yaml`, exit 1 |

The 13 historical findings decompose as: 3× SEC-002 (`kube/base/egress-common.yaml`
ipBlocks) + 1× SEC-003 (no default-deny Ingress) + 1× OBS-001 (`terraform/vpc.tf`,
no flow logs) + 8× FIN-001 (missing `App` tag). SEC-001 and OBS-002 find **nothing**
historically and are proven by their negative controls alone — that is intended,
not a gap.

### Not started

- **The CI workflow has never run.** No commits, no remote, so no Actions run
  exists. README and STATUS both say results come from a local run; do not
  upgrade that wording without a run ID. `re-verify:` `grep -n 'never run' README.md`
- **FIN-002 has never seen real Infracost output.** No `INFRACOST_API_KEY`,
  `infracost` not installed. Both breakdown fixtures are hand-authored, carry a
  `SYNTHETIC-` filename element and a `_synthetic` marker key.
  `re-verify:` `ls gates/fixtures/violations/perfile/ | grep SYNTHETIC`
- **Clause-level coverage is not enforced** (see Invariants).

---

## Locked decisions

Do not relitigate these. Each reason is stated precisely so pick-up can check
whether the reason still holds, not just whether the decision was followed.

1. **Companion repo, not commits to the audited infra repo.** That repo is a
   frozen historical record whose DECOMMISSIONED README is itself an artifact;
   giving it active CI would destroy that.
2. **Zero AWS spend, zero credentials, no `terraform init/plan/apply`.** Rules
   evaluate source directly. If a rule needs credentials, the rule is dropped —
   credentials are never added.
3. **Fixtures are vendored copies pinned by git blob SHA; never submodules or a
   CI-time clone.** Reason: the gate must run offline and the evidence must stay
   verifiable even if the source repository is deleted or made private.
4. **`fixtures/historical/**` is read-only evidence and is never "fixed".**
   Several rules deliberately flag it; that is the self-audit. A rule firing on a
   historical file is a success.
5. **SEC-002 compares against the VPC CIDR, not per-subnet CIDRs.** Reason:
   subnets are `cidrsubnet(var.vpc_cidr, 8, i)`, which no static parser evaluates —
   the values do not exist in the parse. `var.vpc_cidr`'s default *is* a literal.
   SEC-002-DRIFT exists so the pinned constant cannot drift from the HCL.
6. **Broad egress is suppressed by an annotation, not by narrowing the rule.**
   `policy.hossainpazooki.dev/egress-exemption` with a non-empty value. Reason: the
   historical `0.0.0.0/0`-with-RFC1918-excepted egress on :443 is a deliberate
   decision, not a defect; the gate demands it be made explicit rather than calling
   it a bug. An empty value does not exempt.
7. **FIN-001 lives in combined mode.** Reason in
   [[../learnings/2026-08-25-terraform-default-tags-is-provider-wide]] — this is a
   correctness fix, not a convenience. A "pinned default_tags keys" constant was
   considered and **rejected**: it would credit `Environment` in a repo that never
   declares it.
8. **Infracost path = local-run-committed-output.** Reasons: `breakdown` needs an
   API key (a credential, forbidden by decision 2); `vpc.tf` sources a registry
   module at a floating `~> 5.0`, so a CI-time fetch is not reproducible; and a
   live pricing API makes a committed number irreproducible later.
9. **Repo is `network-as-code` with a `gates/` subdirectory** (operator's call,
   2026-08-24). `.github/workflows/` must stay at the repo ROOT — GitHub reads
   workflows nowhere else — so `gate.yml` uses `working-directory: gates`.
10. **The audited repo is not named in docs or STATUS** (operator's call). The
    name survives only in `gates/fixtures/historical/terraform/github-variables.tf`,
    a vendored `variable`-only file that no rule can fire on, deliberately left
    as-is because editing it would break the blob-SHA pin.
11. **`run.sh`, not a Makefile.** `make` is not installed on the Windows box, and
    POSIX `sh` behaves identically in Git Bash and Linux CI.

---

## Reuse map

| Need | Use this, do not rebuild |
|---|---|
| How anything parses | `gates/docs/parse-shape.md` — observed output, not assumption. Read it BEFORE writing a rule. |
| Running anything | `gates/run.sh <target>`: `gate`, `unit`, `conforming`, `violations`, `coverage`, `historical`, `combined`, `verify-provenance`, `parse`, `demo`, `tools` |
| "Is this input actually refused?" | `deny_count()` and `assert_refused()` in `gates/run.sh` — never check `$?` yourself, see Invariants |
| Tolerating an expected non-zero exit | `show_with_count()` in `gates/run.sh` — this is what replaces `\|\| true` |
| A cross-file rule | `gates/policy/combined/security_combined.rego` (SEC-003) is the worked pattern; walk `input[_].contents` |
| Pinning a constant against HCL drift | SEC-002 + SEC-002-DRIFT in `gates/policy/security.rego` |
| Evidence integrity | `gates/fixtures/historical/BLOBSHAS.txt` + `PROVENANCE.md`; `.gitattributes` carries the `-text` rule that keeps them valid |
| Tools | `.tools/conftest.exe` 0.69.0, `.tools/opa.exe` 1.19.1, both sha256-verified. Gitignored; CI installs the same pinned versions. |
| What is claimable | `STATUS.md` is the ceiling. Nothing is cited outside the repo until it appears there with a date. |

---

## Invariants

Break one of these and the repo stops meaning what it says.

1. **A tool error is not a refusal.** conftest exits 1 both for a policy refusal
   and for an unreadable input, so negative controls must count deny messages,
   never check the exit code. Violating this makes an empty directory a passing
   control and the methodology vacuous. Basis:
   [[../learnings/2026-08-25-conftest-exit-code-cannot-distinguish-error-from-refusal]].
   `re-verify:` add an empty dir under `gates/fixtures/violations/combined/` and
   confirm `./run.sh violations` FAILS.
2. **Vacuity guards are per class, not one total.** `np > 0` AND `nc > 0`. A
   single total stays green after deleting every combined fixture — which would
   silently remove the only negative controls FIN-001 and SEC-003 have.
3. **No `|| true` and no `continue-on-error` that suppresses a verdict.** The
   audited repo's Checkov step ended in `|| true` and therefore could never fail;
   correcting that is this repo's reason to exist. The self-audit asserts an EXACT
   count BEFORE any display re-run. (`|| true` on a *capture* whose result is then
   validated is not a verdict suppression — `deny_count()` is the only such use.)
4. **Never edit `gates/fixtures/historical/**`.** Breaks `verify-provenance` and
   destroys the evidence.
5. **`.gitattributes` must keep `gates/fixtures/historical/** -text`.** Without
   it, Git's CRLF normalisation rewrites the bytes on checkout and every blob SHA
   in `BLOBSHAS.txt` fails. This is why `.gitattributes` must land in the SAME
   commit as the fixtures.
6. **`HISTORICAL_EXPECTED` is a claim, not a knob.** Changing it means updating
   STATUS.md in the same change. Never tune a rule to hit a number; if the count
   moves, find out why first. Drift in EITHER direction fails the gate — a rule
   that silently stops firing is as bad as a new finding.
7. **Every rule ID needs a fixture that `./run.sh violations` exercises.** A rule
   covered only by `opa test` is not covered by the negative-control loop. That
   gap shipped twice (FIN-002, then a SEC-001 clause). `./run.sh coverage` now
   guards the ID level — **but not the clause level.** A rule with several deny
   bodies sharing one ID counts as covered when any one fires, so a clause can
   still be deleted without turning the gate red. Known and unfixed.
8. **Rego v1 only**, package `main`, `deny` never `warn`. All families share one
   package, so `deny` is the UNION across families: a conforming fixture must
   satisfy all three, and a unit test counting `deny` must scope to its own rule-ID
   prefix or it is brittle and possibly vacuous.
9. **Claims stay tiered.** "decommissioned" is never used alone — always paired
   with the API-verified destroy. Banned vocabulary: "production policy
   enforcement", "at scale", "battle-tested", "admission controller". README ≤ 120
   lines (`wc -l README.md` → 116).

---

## Open / next

**First thing to pick up: commit the initial history and push, then let CI run.**
This is the one claim in the repo that is written down but unproven. The commit
commands are staged by concern and were produced but NOT executed — see the end of
the session transcript. Order: scaffold+evidence (must include `.gitattributes`,
invariant 5) → rules → CI → docs.

Blockers and cautions in its way:

1. **`PLAN.md` is deliberately unstaged and stale.** It still opens "Status:
   PROPOSED… Nothing below is built" and its prediction table (K=4, FIN-001 "TBD")
   is superseded by STATUS.md's measured 13. Decide: delete it, or stamp
   "SUPERSEDED — see STATUS.md". Do not commit it as-is. *(Asked, unanswered.)*
2. **After the first CI run**, update the README paragraph that currently says the
   workflow "has never run", and STATUS.md's CI line — and only then, with a run
   ID. If the run is red, that is the finding, not an embarrassment.
3. **FIN-002's real measurement** needs an `INFRACOST_API_KEY`. Until then, the
   `SYNTHETIC-` prefix and `_synthetic` marker must survive every edit; they are
   what keeps a hand-authored number from reading as a measurement.
4. **Clause-level coverage** (invariant 7) is the one known hole in the
   methodology. Closing it needs per-clause message-shape tracking.
5. `~/dev/.git/info/exclude` has `network-as-code/` so the umbrella repo does not
   swallow this one. Local only; not committable, and easy to lose on a new machine.

### Provenance caveat pick-up should know

The vendored bytes came from the audited repo's upstream remote at ref
`95df6efd8be92dc589e2cbd0124c79b78922dade`, **not** from the local monorepo copy —
the local copy had diverged (`kube/base/kustomization.yaml` differs). Vendoring
from the local tree would have produced a PROVENANCE.md whose cited SHA did not
match its own bytes. `verify-provenance` proves the files are unmodified **since
vendoring**; it does not re-check them against the ref, which would need the
network. Equality with the ref was established once, at vendoring time.
