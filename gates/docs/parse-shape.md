# Parse shape - the contract every rule is written against

Produced by the Phase 0 spike on 2026-08-24. Every fact below was observed by
running the pinned tools against the vendored fixtures, not assumed. If a rule
disagrees with this document, the rule is wrong until this document is re-run
and updated.

Regenerate with `./run.sh parse`.

## Pinned toolchain

| Tool | Version | Verification |
|---|---|---|
| conftest | 0.69.0 (embeds OPA 1.19.0) | `conftest_0.69.0_Windows_x86_64.zip` sha256 `be95f90cd22d00e709a7ad37bdac357c103b4f81d92dc51ca75a60e5f3905cf5`, matched against upstream `checksums.txt` |
| opa | 1.19.1 | `opa_windows_amd64.exe` sha256 `fc932e644652d5634bc0d7a5e5f455dd26ebf5b243682a81eddf6d387a901e2e`, matched against upstream `.sha256` |

Docker was NOT used - the daemon is not running on this machine. Binaries live
in `.tools/` (gitignored); CI installs the same pinned versions.

## Rego dialect: v1 is MANDATORY

OPA 1.x parses Rego v1. Rules MUST use the `contains` / `if` forms. A v0-style
`deny[msg] { ... }` is a parse error, not a deprecation warning.

```rego
package main

deny contains msg if {
	# ...
	msg := sprintf("SEC-001: %s", [name])
}
```

- Package is `main` (conftest's default namespace). Do not invent per-family
  packages unless `run.sh` is updated to pass `--namespace`. Because all
  families share one package, `deny` is the UNION across families.
- `deny` fails the run. `warn` does not. Every rule in this repo uses `deny`.
- `conftest test` exits **1** when any `deny` fires, **0** when none do.
  Verified by smoke test.

## HCL2 (`.tf`) - conftest parses natively, no `terraform init`

**The single most important shape fact: HCL blocks parse to LISTS, not objects.**

```
input.resource.aws_security_group.rds        -> LIST, index it: [_]
input.resource.aws_security_group.rds[0].ingress -> LIST of blocks
input.module.vpc                             -> LIST
input.variable.vpc_cidr                      -> LIST
input.data.aws_availability_zones.available  -> LIST
input.locals                                 -> LIST
```

Arguments (as opposed to blocks) keep their natural type:

```
input.resource.aws_security_group.rds[0].tags  -> MAP  {"Component": "database", ...}
input.module.vpc[0].enable_nat_gateway         -> bool true
input.module.vpc[0].source                     -> "terraform-aws-modules/vpc/aws"
```

So the idiomatic rule walk is:

```rego
some name, i
sg := input.resource.aws_security_group[name][i]
some j
block := sg.ingress[j]
```

### Unresolved expressions are opaque strings

Nothing is evaluated. Interpolations, function calls, and comprehensions all
come back as `"${...}"` strings:

```json
"cidr":            "${var.vpc_cidr}",
"name":            "${var.project_name}-vpc",
"private_subnets": "${[for i, az in local.azs : cidrsubnet(var.vpc_cidr, 8, i + 1)]}",
"version":         "~> 5.0"
```

**This is why SEC-002 compares against the VPC CIDR and not per-subnet CIDRs.**
`cidrsubnet()` is never evaluated by any static parser, so the subnet CIDRs do
not exist as values anywhere in the parse. Confirmed, not assumed.

### Variable defaults ARE readable literals

```json
"variable": { "vpc_cidr": [ { "default": "10.0.0.0/16",
                              "description": "CIDR block for the VPC",
                              "type": "${string}" } ] }
```

This is the anchor SEC-002 uses: read `input.variable.vpc_cidr[0].default`, then
`net.cidr_contains(vpc_cidr, ipblock_cidr)`.

Note `type` also arrives as `"${string}"` / `"${number}"` - do not test it as a
bare word.

## `.tfvars` - parses natively, flat map, no `--parser` flag needed

```json
{ "environment": "dev", "single_nat_gateway": true, "eks_node_min_size": 2, ... }
```

No `variable` wrapper, no lists. A tfvars rule reads keys directly off `input`.

## YAML - plain object, as expected

```
input.kind                          -> "NetworkPolicy"
input.spec.policyTypes              -> ["Egress"]
input.spec.egress[_].to[_].ipBlock.cidr
input.metadata.annotations["..."]   -> exemption lookup
```

## Cross-file rules need `--combine`, and the input shape CHANGES

Default `conftest test` evaluates **one file at a time**, so a rule like SEC-003
("this namespace has an egress policy but no default-deny ingress policy")
cannot be expressed - no single file knows about the others.

`conftest test --combine` wraps every input into one array:

```json
[ { "path": "kube/base/egress-common.yaml", "contents": { ...the doc... } },
  { "path": "kube/base/namespace.yaml",     "contents": { ...the doc... } } ]
```

So a combined rule walks `input[_].contents`, and `input[_].path` is available
for the message. **A rule written for combined mode will NOT work in per-file
mode and vice versa.** They are separate conftest invocations with separate
policy directories:

- `policy/` - per-file rules (SEC-001, SEC-002, SEC-002-DRIFT, OBS-001,
  OBS-002, FIN-002)
- `policy/combined/` - cross-file rules (SEC-003, and FIN-001)

`run.sh` and CI must keep these two invocations distinct.

FIN-001 lives in combined mode for a *semantic* reason, not a convenience one:
Terraform's provider-level `default_tags` applies to every resource in the root
module regardless of which `.tf` file declares it, so a per-file rule reported
`Environment` missing on resources whose provider block sat in `versions.tf`.
Which file a resource occupies is a source-layout choice with no meaning to
Terraform, so any rule reading a provider-wide fact must see the whole module.

## Known cosmetic quirks

- `>` in version constraints is HTML-escaped: `"~> 5.0"`. Compare with the
  escaped form or use `contains()` on a substring that avoids it.
- Comments are dropped by the parser. A rule can never see a `#` justification;
  that is why the SEC-002 exemption is an **annotation**, not a comment.
