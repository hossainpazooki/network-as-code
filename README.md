# network-as-code

I designed, operated, and then tore down the AWS platform this repo audits. The
teardown was confirmed by probing the AWS API afterwards, not by reading the
apply log: `terraform state list` returns 0 resources, and the EKS cluster, the
VPC and its 9 subnets, the NAT gateway and its Elastic IP, the ElastiCache
replication group, all 3 Secrets Manager secrets, the cluster log group and
every project IAM role were each checked gone against the API on 2026-08-03.
That platform is decommissioned with an API-verified destroy, so no claim here
can be settled by pointing at something running. Its configuration is instead
vendored into this repo as read-only evidence, pinned file-by-file by git blob
SHA (`gates/fixtures/historical/`, source commit `95df6efd`).

## The gap this closes is enforcement

That platform had scanning. What it did not have was refusal: its Checkov steps
ended in `|| true` (`.github/workflows/infra-security-scan.yml`, lines 26 and
43), so a finding produced an artifact and a green check. This repo forbids
`|| true` and `continue-on-error` anywhere in its own workflow, and every rule
ships with a fixture the gate must REFUSE -- a rule with no refusing test does
not merge, because a gate that cannot fail is not a gate.

```
$ cd gates && ./run.sh demo

=== DEMO: the gate refusing a violation ===
FAIL - fixtures/violations/perfile/netpol-wide-ipblock.yaml - main - SEC-002: egress ipBlock 10.0.0.0/8 is broader than the declared VPC CIDR 10.0.0.0/16 (NetworkPolicy egress-wide-demo, egress[0].to[0])

13 tests, 12 passed, 0 warnings, 1 failure, 0 exceptions
conftest exit code: 1 (non-zero = refused)
```

## The self-audit: what the rules find in my own prior config

`./run.sh historical` runs all three families against the vendored config and
asserts an EXACT finding count (13). Findings are expected there; the count is
the assertion, so a rule that silently stops firing fails the build just as
loudly as a new finding does.

| Rule | Findings | Where |
|---|---|---|
| FIN-001 allocation tags | 8 | combined over `terraform/` -- `ecr.tf` (1), `elasticache.tf` (3), `rds.tf` (1), `secrets.tf` (3); every message names `App` and nothing else |
| OBS-001 VPC without flow logs | 1 | `terraform/vpc.tf` -- `module "vpc"` sets no `enable_flow_log` |
| SEC-002 egress broader than the VPC | 3 | `kube/base/egress-common.yaml` -- two `10.0.0.0/8` ipBlocks and one `0.0.0.0/0`, against a `10.0.0.0/16` VPC |
| SEC-003 egress policy, no default-deny ingress | 1 | combined over `kube/base/egress-common.yaml` + `kube/overlays/dev/egress-app.yaml` -- 2 NetworkPolicies, both Egress-only |

**The historical fixtures are not fixed, on purpose.** They are evidence of what
I actually shipped; editing them would break the blob-SHA provenance check and
destroy the thing being measured. `./run.sh verify-provenance` re-derives all 22
blob SHAs on every run.

FIN-001 used to report `Environment` missing on all 8, which was false:
`provider "aws" { default_tags }` in `terraform/versions.tf` declares it, and in
Terraform that is a property of the provider configuration, applying to the
whole root module no matter which `.tf` file a resource sits in. A per-file rule
cannot see across files, so it was reporting something untrue -- which is how a
gate teaches people to ignore it. FIN-001 now runs in `--combine` mode over the
terraform root module and credits the union of every `default_tags` block in the
set. The count is unchanged at 8, because `App` really is absent everywhere; the
messages are what changed. Nothing was tuned to hold the number.

## Rules that find nothing, and why they still count

SEC-001 (security group open to the world) finds **0** in my config -- there is
no `0.0.0.0/0` in any of the 12 vendored `.tf` files. OBS-002 (flow logs without
a retention period) also finds **0**, because it is gated on flow logs existing
at all and OBS-001 already fired. Neither is dead weight and neither is proven
by a finding: each is proven by its negative control, a fixture the gate must
refuse. There are 16 such fixtures -- 12 single-file and 4 directory sets -- and
all 16 are asserted refused on every run.

FIN-002 (Infracost budget delta) has a refusing fixture in the negative-control
loop like every other rule, but no measurement behind it: both its breakdown JSONs are
hand-authored, carry a `SYNTHETIC-` filename element and a `_synthetic` marker
key, and no real `infracost breakdown` has ever run against this repo (no API
key). Its ceilings come from `gates/policy/budget.json`, which the gate loads
with `--data policy`; a unit test fails if the rule's embedded fallback copy
drifts from that file. See `STATUS.md`.

Not built: aggregating the flow logs that OBS-001 asks for into egress-GB-per-
app reporting -- the plane-1 to plane-5 extension -- is a direction, not code in
this repo.

## Run it

```
cd gates
./run.sh demo     # 30 seconds: watch the gate refuse a violation
./run.sh gate     # the full build: provenance, unit, conforming, violations, self-audit
```

Targets: `verify-provenance`, `unit`, `conforming`, `violations`, `combined`,
`historical`, `parse`, `demo`, `gate`, `tools`. The same five are DEFINED as separate
jobs in `.github/workflows/gate.yml`, triggered on push and pull request, with
the pinned conftest 0.69.0 / OPA 1.19.1 binaries sha256-verified against the
publishers' checksums before they are executed. That workflow has run exactly
once, on 2026-08-25, and it failed: `gates/run.sh` was committed without its
executable bit, so the first job exited 126 on `Permission denied` and the four
jobs that evaluate policy never started. **No rule has yet been evaluated in
CI**, and every result quoted here comes from a local run. Zero credentials,
zero spend: no AWS, no `terraform init/plan/apply`, no Infracost call in CI.

## Layout

```
gates/policy/            per-file rules (conftest evaluates ONE parsed file)
gates/policy/combined/   cross-file rules (--combine; input is a LIST of docs)
gates/policy/budget.json FIN-002 ceilings, loaded as data via --data policy
gates/tests/             opa unit tests, one file per family
gates/fixtures/historical/   vendored evidence, blob-SHA pinned, NEVER edited
gates/fixtures/conforming/   must PASS every family, not just their own
gates/fixtures/violations/   must each be REFUSED
gates/docs/parse-shape.md    the observed parse shape every rule is written against
```

Rego is v1 (`deny contains msg if { ... }`); every policy file is package
`main`, so `deny` is the union across families -- a conforming fixture has to
satisfy all three.
