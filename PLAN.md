# PLAN - network-as-code-gates

> **SUPERSEDED 2026-08-26 - historical document, do not cite.**
>
> This was the pre-build plan. It was written before any of it existed, and its
> predictions have been overtaken: the historical finding count it lists as TBD
> measured 13, FIN-001 moved to combined mode, FIN-003 did not exist, and the
> `make` targets it references were never built (the runner is `gates/run.sh`).
>
> **`STATUS.md` is the ceiling of what is true about this repo.** Read that
> instead. This file is kept only to show what was predicted before the work,
> against what the work found.


Status when written: PROPOSED, awaiting approval, nothing below built.
Status now: BUILT and superseded - see the notice above and STATUS.md.
Authored 2026-08-24 against SPEC: network-as-code-gates.

## 0. Recon actually performed (facts, not assumptions)

All read via `git show` in the ~/dev umbrella and cross-checked against the
public repo with `gh api`. Each is re-derivable on demand.

| Fact | Source | Value |
|---|---|---|
| Source subtree | `gh repo view` | platform-infrastructure subtree of the local monorepo (name withheld), default branch `master` |
| Provenance commit | `gh api .../commits/master` | `95df6efd8be92dc589e2cbd0124c79b78922dade` (2026-08-03T16:51:28Z, "docs: mark infra decommissioned...") |
| Local copy fidelity | git blob id vs GitHub blob sha | `terraform/vpc.tf` -> `2ac14906...` MATCH; `kube/base/egress-common.yaml` -> `9b7a29a5...` MATCH |
| On-disk copy | `ls` | ABSENT - the infra subtree is an unstaged deletion in ~/dev. Vendor from git, not disk. |
| `var.vpc_cidr` default | `variables.tf:146-150` | `"10.0.0.0/16"` (a literal, so a static parser can read it) |
| `0.0.0.0/0` in HCL | grepped every `.tf` under `terraform/` and `modules/` | ZERO occurrences |
| provider `default_tags` | `versions.tf` | supplies `Project`, `ManagedBy`, `Environment` |
| NetworkPolicies | enumerated every file under `kube/` | 3 total, ALL `policyTypes: [Egress]`, zero Ingress-type |
| Checkov `|| true` | `.github/workflows/infra-security-scan.yml:26,43` | CONFIRMED, on both the terraform and kubernetes scan steps |
| Local toolchain | `command -v` | terraform 1.15.0-dev, docker 29.3.1, gh 2.93.0 present; **opa, conftest, infracost, checkov ALL ABSENT** |

## 1. Predicted findings against the vendored historical config

Targets derived by reading the fixtures by hand. NOT results; nothing here
enters STATUS.md or README until a rule actually emits it.

| Rule | Historical findings | Evidence |
|---|---|---|
| SEC-001 open ingress CIDR | **0** | zero `0.0.0.0/0` in any `.tf` |
| SEC-002 netpol ipBlock broader than VPC CIDR | **2** | `egress-common.yaml` allows `10.0.0.0/8` to :5432 and to :6379; the VPC is `10.0.0.0/16` (a /8 is 256x the VPC) |
| SEC-003 egress policy without default-deny ingress | **1** | namespace `institutional-defi`: 3 NetworkPolicies, all Egress-only |
| OBS-001 VPC without flow logs | **1** | `module "vpc"` sets no `enable_flow_log` |
| OBS-002 flow log without retention | **0** | conditional on OBS-001 not firing; negative control only |
| FIN-001 allocation tags | TBD - see OQ-1 | as written in the spec it false-positives on `Environment` (provider `default_tags`) |
| FIN-002 budget delta | 1 by construction | dev + `single_nat_gateway=false` -> 3 NAT gateways |

K = 4 confirmed-by-inspection findings for phases 1-2, FIN-001 pending a ruling.
Two rules (SEC-001, OBS-002) find nothing in my own config. That is a feature,
and README should say it plainly: those rules are proven by their negative
control, not by a finding.

## 2. Phases (phase = one mergeable commit set)

### Phase 0 - scaffold + parser-shape spike  [BLOCKING, ~45 min]

Every Rego rule is written against conftest's HCL2 parse shape. Write rules
against an imagined AST and phase 1 is wasted. Pin the shape first.

1. `git init` at `~/dev/network-as-code-gates`; add `network-as-code-gates/` to
   `~/dev/.git/info/exclude` so the umbrella never swallows it as an embedded repo.
2. Vendor 6 files from `git show 95df6ef:<path>`:
   `terraform/vpc.tf`, `terraform/variables.tf`, `terraform/versions.tf`,
   `terraform/envs/dev.tfvars`, `kube/base/egress-common.yaml`,
   `kube/overlays/dev/egress-app.yaml`.
   (`versions.tf` is beyond the spec's list - FIN-001 cannot see `default_tags`
   without it. `prod.tfvars` deferred to phase 3.)
3. `fixtures/historical/PROVENANCE.md`: repo URL, commit `95df6ef...`, date, and
   **the git blob SHA of each vendored file**, so a third party can run
   `git hash-object` and refute the copy. Stronger than a bare repo SHA.
4. Pin the toolchain: conftest and opa versions in `.tool-versions` plus a
   `Makefile` that shells out via docker
   (`docker run --rm -v "$PWD:/project" openpolicyagent/conftest:<ver>`), native
   binaries as the fast local path. Windows note: Git Bash needs
   `MSYS_NO_PATHCONV=1` on the `-v` mount.
5. **Spike gate:** `conftest parse` must succeed on all 6 fixtures. Two known
   risks: (a) `vpc.tf` uses `for` comprehensions and `cidrsubnet(...)`, so
   unresolved expressions may parse as opaque strings or fail outright;
   (b) `.tfvars` may not auto-map to the hcl2 parser (`--parser hcl2` needed).
   **Fallback if parse fails: `tmccombs/hcl2json` as a static converter, then
   opa/conftest over JSON.** Still zero credentials, zero spend.
6. Commit the observed shape to `docs/parse-shape.md`. That file is the contract
   every rule is written against.

Exit: `./run.sh parse` prints a tree for all 6 fixtures; `docs/parse-shape.md` exists.

### Phase 1 - security family + negative controls + CI  [the evening core]

| Rule | Deny condition | Conforming fixture | Violation fixture |
|---|---|---|---|
| SEC-001 | `ingress` block whose `cidr_blocks` contains `0.0.0.0/0` (also `::/0`) | `conforming/sg-scoped.tf` (SG-referenced ingress, mirrors `rds.tf`) | `violations/sg-open-world.tf` (0.0.0.0/0 on :5432) |
| SEC-002 | NetworkPolicy egress `ipBlock.cidr` not contained by the declared `vpc_cidr`, absent an exemption annotation | `conforming/netpol-scoped.yaml` (`10.0.0.0/16`) | `violations/netpol-wide-ipblock.yaml` (`10.0.0.0/8` to :5432) and `violations/netpol-world-egress.yaml` (`0.0.0.0/0`) |
| SEC-003 | a namespace's manifest set has an Egress NetworkPolicy but no policy with `policyTypes: [Ingress]` and an empty `ingress:` | `conforming/ns-with-default-deny/` (2 files) | `violations/ns-egress-only/` (mirrors historical) |

Two deliberate narrowings vs the spec, both toward the smallest artifact:

- **SEC-002 compares against the VPC CIDR, not per-subnet CIDRs.** Subnets are
  computed as `cidrsubnet(var.vpc_cidr, 8, i+1)`; no static parser evaluates
  that. `var.vpc_cidr`'s default IS a literal, so Rego reads it straight from
  the parse and uses the `net.cidr_contains` builtin. Strictly smaller, no data
  file, and it still catches all three historical ipBlocks. A per-subnet version
  would need a hand-maintained CIDR table that can silently drift from the HCL -
  a worse artifact.
- **SEC-002 needs an exemption mechanism**, because the historical `0.0.0.0/0`
  with RFC1918 excepted (port 443, for Secrets Manager / S3 / ECR) is a design
  decision, not a defect. Deny by default; allow only when the policy carries
  `policy.hossainpazooki.dev/egress-exemption: "<reason>"`. That converts an
  argument into a reviewable annotation. See OQ-2.

`policy/lib/` is NOT needed in phase 1 - `net.cidr_contains` is a builtin.
Create it when a second rule actually needs a shared helper.

Tests: `tests/security_test.rego`, at least one deny case and one allow case per rule.

CI job graph (`gate.yml`), triggers PR + push main + workflow_dispatch:

```
  unit ......... opa test policy/ tests/          (fails -> everything stops)
    |
    +--> conforming ... conftest test fixtures/conforming/ --policy policy/
    |                   expect exit 0
    +--> violations ... for each file in fixtures/violations/:
    |                     conftest test <file> --policy policy/
    |                     expect NON-ZERO; if it exits 0 -> FAIL THE JOB
    +--> historical ... conftest test fixtures/historical/ --policy policy/
                        expected non-zero, asserted by exact count:
                        test "$COUNT" -eq 4
```

The violations job is a loop with an inverted assertion, not `continue-on-error`.
The historical job is the only place a non-zero conftest exit is tolerated, and
it is tolerated by an **explicit expected-count assertion**, never by `|| true`.
That keeps §6 intact while letting the self-audit findings stay visible - and it
means a rule silently ceasing to fire also breaks the build.

Exit: acceptance 1, 2, 5 met for family 1; STATUS.md entry #1 dated.

### Phase 2 - observability family  [same evening]

| Rule | Deny condition | Conforming | Violation |
|---|---|---|---|
| OBS-001 | `module "vpc"` or `resource "aws_vpc"` with no truthy `enable_flow_log` and no `aws_flow_log` targeting it | `conforming/vpc-flowlogs.tf` | `violations/vpc-no-flowlogs.tf` (mirrors historical) |
| OBS-002 | flow logs enabled but no `flow_log_cloudwatch_log_group_retention_in_days` (or `retention_in_days` on the log group) | `conforming/vpc-flowlogs.tf` (retention 90) | `violations/vpc-flowlogs-no-retention.tf` |

OBS-002 must be gated on OBS-001 not firing, so a flow-log-less VPC produces one
finding, not two, plus a test asserting exactly that. Double-counting is how
finding counts become lies.

### Phase 3 - finops family  [second dated STATUS entry, not the evening core]

| Rule | Deny condition | Conforming | Violation |
|---|---|---|---|
| FIN-001 | taggable resource missing a required allocation tag, where a tag counts as present if on the resource OR in provider `default_tags` | `conforming/tagged.tf` | `violations/untagged.tf` |
| FIN-002 | committed Infracost JSON shows a monthly delta above the threshold in `policy/budget.json` | `fixtures/infracost/dev-single-nat.json` | `fixtures/infracost/dev-per-az-nat.json` |

**Infracost path recommendation: LOCAL RUN, COMMITTED OUTPUT.** Three reasons,
heaviest first:

1. `infracost breakdown` needs `INFRACOST_API_KEY` to reach the pricing API.
   That is a credential in CI, which §2 forbids. No amount of cleverness gets
   around it.
2. `vpc.tf` sources the registry module `terraform-aws-modules/vpc/aws ~> 5.0`,
   so Infracost's HCL parser must fetch it at run time - a network dependency on
   a floating version. A gate whose input can move under it is not a gate.
3. §8 requires numeric claims to be reproducible from the repo. A live pricing
   API makes the dollar figure irreproducible six months from now. Committed
   JSON, stamped with infracost version, run date, and "pricing as of", is
   reproducible indefinitely.

So: run Infracost once locally, commit both JSON outputs, let Rego compare. CI
stays hermetic and credential-free; the negative control still runs in CI.
STATUS.md records `[Infracost path taken: local-run-committed-output]`.
Blocker: infracost is not installed and the free key needs a signup - see OQ-4.

### Phase 4 - Checkov  [RECOMMEND DEFERRING, possibly dropping]

See over-scope flags.

## 3. Open questions, ranked by whether they block phase 1

**OQ-1 (blocks phase 3 only) - FIN-001 tag semantics.** The spec's rule ("deny
any resource missing `Component`, `Environment`, `App`") false-positives on
every resource for `Environment`, because the provider supplies it through
`default_tags`. Left as written, the gate is stricter than the thing it models -
an always-fires gate is one a human learns to ignore.
*Recommendation:* a tag is satisfied by the resource OR by provider
`default_tags`. Under that, historical = `Environment` OK, `Component` present
on most resources, `App` present on **none**, so the rule fires on roughly 15
resources. Report that as one aggregated line ("N resources missing `App`"), not
15 README bullets. Needs a yes/no before phase 3, not before phase 1.

**OQ-2 (blocks phase 1, small) - SEC-002 exemption mechanism.** Does the
deliberate `0.0.0.0/0`-except-RFC1918 egress on :443 get an annotation
exemption, or is it simply a fourth finding? The annotation is more honest - the
rule would otherwise flag a decision I would make again - but it adds a
mechanism.
*Recommendation:* annotation exemption. K becomes 4 rather than 5, and the
exemption itself is reviewable in the diff.

**OQ-3 (blocks phase 0, trivial) - directory name.** The directory created is
`network-as-code`; the spec and the intended GitHub repo are
`network-as-code-gates` (verified: that repo does not exist on GitHub yet).
*Recommendation:* rename to `network-as-code-gates`.

**OQ-4 (blocks phase 3 only) - Infracost account.** The local-run path still
needs `INFRACOST_API_KEY` on *your machine* for the one-time run. Acceptable? If
not, the fallback is hand-authored deltas from AWS's public NAT Gateway price
with the source URL cited, which downgrades the tier claim from "Infracost:
operated" to "familiar" - and STATUS.md would say so.

**OQ-5 (blocks nothing) - the deleted working tree.**
The infra subtree is an unstaged deletion in ~/dev. Vendoring
comes from git, so it does not block me, but whether that deletion gets
committed or reverted is your call. Not mine to fix.

## 4. Over-scoped for the one-evening core

1. **Checkov + triaged `.checkov.baseline` (§4, §6).** Checkov over this
   terraform will emit dozens of findings, each needing an in-line
   justification per §6. That is an evening by itself, and §2 already says
   Checkov is supporting evidence, not the story. *Cut from the core; revisit
   only if the README needs a second corroborating engine.*
2. **`policy/lib/` (§3).** `net.cidr_contains` is a builtin and tag lookup is a
   one-liner. An empty `lib/` is scaffolding pretending to be structure.
3. **Per-subnet CIDR comparison (§4, family 1, rule 2).** Not statically
   computable - see the phase 1 narrowing.
4. **`prod.tfvars` and the prod overlay fixtures.** They add nothing to phases
   1-2; the dev pair carries the demo. Defer to phase 3.
5. **Infracost in CI (§4, family 3).** See the path recommendation.

## 5. Acceptance-criteria trace

| Criterion | Where met |
|---|---|
| 1 `opa test` green, every rule unit-tested | phases 1-3, `tests/` |
| 2 CI both directions; job fails if a violation passes | phase 1, `gate.yml` violations job |
| 3 >=1 rule per family flags historical | SEC-002 / SEC-003 (F1), OBS-001 (F2), FIN-001 (F3, pending OQ-1) |
| 4 STATUS.md dated; README <=120 lines, verified-destroy before "decommissioned" | phase 1 and phase 3 entries |
| 5 30-second demo | `./run.sh demo` = one conftest command refusing the per-AZ-NAT dev fixture (phase 3), or for the phase-1 core, refusing `netpol-wide-ipblock.yaml` |
| 6 evening = families 1-2 + controls | phases 0-2 |

Note on criterion 5: the spec's named demo (per-AZ NAT in dev) lives in the
finops family, i.e. phase 3 - so **the evening core does not ship the spec's
headline demo**. Either accept a security-family demo for the core, or accept
that criterion 5 lands with the second STATUS entry. Flagged rather than
silently substituted.
