# CLAUDE.md - network-as-code

## What this repo is

A fail-closed policy gate (conftest / OPA Rego v1) over infrastructure-as-code,
auditing the author's own prior operated AWS platform, vendored as read-only
evidence. Methodology: **every rule ships with a fixture the gate must REFUSE**,
and the build fails if a violation fixture is ever accepted.

## Layout

```
gates/policy/*.rego              per-file rules (input = ONE parsed file)
gates/policy/combined/*.rego     cross-file rules (--combine; input = LIST of docs)
gates/tests/*_test.rego          opa unit tests, one file per family
gates/fixtures/historical/       vendored evidence, blob-SHA pinned
gates/fixtures/conforming/       must PASS
gates/fixtures/violations/       must be REFUSED
gates/docs/parse-shape.md        observed parse shape - the rule-writing contract
.github/workflows/gate.yml       CI, one job per run.sh target
README.md / STATUS.md            claims; STATUS.md is the ceiling of what is true
```

## Commands (all from `gates/`)

`./run.sh gate` is the authoritative build: verify-provenance -> unit ->
conforming -> violations -> historical, ending in `GATE GREEN`. Other targets:
`combined`, `parse`, `demo`, `tools`. Nothing needs credentials or network.

## Two hard rules

1. **Never edit anything under `gates/fixtures/historical/`.** Those 22 files are
   verbatim evidence pinned by git blob SHA in `BLOBSHAS.txt`. Rules flag
   findings in them on purpose - that is the self-audit. Editing one breaks
   `./run.sh verify-provenance` and destroys the evidence. A rule firing on a
   historical file is a SUCCESS, not a bug to fix.
2. **Never add `|| true` or `continue-on-error` to the workflow.** The repo being
   audited shipped a Checkov step that ended in `|| true` and therefore could
   never fail; correcting that is this repo's reason to exist. The historical
   self-audit asserts an EXACT finding count (`HISTORICAL_EXPECTED` in `run.sh`)
   instead of swallowing the exit code - drift in either direction is a failure.

## Writing rules

Read `gates/docs/parse-shape.md` first; it is observed output, not assumption.
HCL2 blocks parse to LISTS (`input.resource.aws_vpc.main[0]`), `${var.x}` stays
an opaque string and is never evaluated, `.tfvars` parse to a flat map, and
`--combine` changes the input to a list of `{path, contents}` - so a combined
rule cannot work per-file, or vice versa. Rego v1 only
(`deny contains msg if { ... }`), package `main`, `deny` never `warn`. Message
format: `<RULE-ID>: <what is wrong> (<where>)`.

All families share package `main`, so `deny` is the UNION across families: a
conforming fixture must satisfy all three, and a unit test that counts `deny`
must scope to its own rule-ID prefix or it will be brittle and possibly vacuous.

## Git

Do not commit or push. Output the commit command for the author to run.
