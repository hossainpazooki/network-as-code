# fixtures/infracost/ - FIN-002 / FIN-003 fixtures: where they are, how to replace them

**The JSON files no longer live here.** They were moved into the directories
`run.sh` actually globs, because a negative control that CI never runs is not a
negative control:

| Scenario | File | Asserted by |
|---|---|---|
| dev, `single_nat_gateway = true`, `totalMonthlyCost` 221.33 | `fixtures/conforming/perfile/fin-SYNTHETIC-infracost-single-nat.json` | `./run.sh conforming` - must PASS |
| dev, `one_nat_gateway_per_az = true`, `totalMonthlyCost` 287.03 | `fixtures/violations/perfile/fin-SYNTHETIC-infracost-per-az-nat.json` | `./run.sh violations` - must be REFUSED |
| failed module load, `totalMonthlyCost` "0", zero resources | `fixtures/violations/perfile/fin-SYNTHETIC-infracost-broken-module-load.json` | `./run.sh violations` - must be REFUSED |

This directory is kept as the documented home for the replacement procedure
below. Nothing under it is evaluated by any gate target.

## These numbers are still not measurements

All three files are hand-authored. Two markers make that visible and are both
load-bearing - do not drop either without replacing the contents with real
output:

- the `SYNTHETIC-` element of each filename, and
- the top-level `_synthetic` key inside each file.

## What a real run established on 2026-08-26

Infracost **has** now been installed (v0.10.45) and authenticated, and real
breakdowns were run. **The output was deliberately not committed**, so the
fixtures above remain hand-authored by decision rather than by inability.
Recorded here because it bears on how the replacement should be done:

- **The schema FIN-002 reads is correct** for v0.10.x, confirmed against real
  output: `projects[].name`, `projects[].breakdown.totalMonthlyCost` as a
  decimal string. Infracost v2.x renames both; see `docs/learnings/`.
- **Measured totals** (from a tree with the missing modules restored):
  dev single-NAT `594.416` over 12 costed resources, dev per-AZ-NAT `660.116`
  over 14, prod `853.404` over 14. The synthetic 221.33 / 287.03 model NAT
  gateways only and are roughly a third of the real figures.
- **A failed parse is silent.** Run against this repo's vendored tree as it
  stands, infracost cannot resolve `../modules/iam/*`, prices nothing, reports
  `totalMonthlyCost` "0" and exits 0. FIN-003 exists to refuse exactly that.

## Replacing them with a real run

Two things must be true first, and neither was obvious before the run above.

**1. The nine missing module files must be present.** `terraform/iam.tf` sources
`../modules/iam/{builder,pod,provisioner}`, which exist at ref `95df6ef` but sit
one directory ABOVE the vendored subtree and were never vendored with it.
Without them infracost detects zero resources. Vendoring them extends
`BLOBSHAS.txt` from 22 to 31 entries and will change the historical finding
count that `./run.sh historical` asserts exactly - recompute it, do not tune it.

**2. Use directory mode, not a plan file.** An earlier revision of this file
said to pass `--path <terraform-plan.json>`. Producing that means
`terraform init` + `plan` + `show -json`, and `terraform plan` against this
config needs AWS credentials - which the spec forbids outright. Infracost's
directory mode parses the HCL itself and needs no AWS access:

```
infracost breakdown --path <terraform-dir> --terraform-var-file envs/dev.tfvars \
  --project-name dev --format json --out-file <target>
```

**Run it against a COPY, never against `fixtures/historical/`.** Infracost
writes a `.infracost/terraform_modules/` cache into its working tree - on
2026-08-26 that put 822 unrecorded files inside the evidence tree, and every
blob SHA still matched. `./run.sh verify-provenance` now fails on any unrecorded
file, which is the guard that incident produced.

Then drop the `SYNTHETIC-` filename element and the `_synthetic` key, and update
`STATUS.md` in the same change - that is where the "not a measurement" claim
lives.

## Thresholds

`policy/budget.json` holds the per-environment ceilings and is the enforced
source: `run.sh` passes `--data policy`, which exposes its top-level keys as
`data.dev` / `data.prod`. **Its current values are derived from the synthetic
figures and are stale against measurement**: dev = 250.0 sits ~2.4x below the
real single-NAT baseline of 594.42. Adopting real fixtures requires re-deriving
it; any value between 594.42 and 660.12 preserves the intent that single-NAT
passes and per-AZ refuses. prod = 900.0, long labelled a placeholder, happens to
sit 5.5% above the measured 853.40.
