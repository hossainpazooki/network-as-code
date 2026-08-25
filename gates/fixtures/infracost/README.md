# fixtures/infracost/ - FIN-002 Infracost fixtures: where they are, how to replace them

**The JSON files no longer live here.** They were moved into the directories
`run.sh` actually globs, because a negative control that CI never runs is not a
negative control:

| Scenario | File | Asserted by |
|---|---|---|
| dev, `single_nat_gateway = true`, `totalMonthlyCost` 221.33 | `fixtures/conforming/perfile/fin-SYNTHETIC-infracost-single-nat.json` | `./run.sh conforming` - must PASS |
| dev, `one_nat_gateway_per_az = true`, `totalMonthlyCost` 287.03 | `fixtures/violations/perfile/fin-SYNTHETIC-infracost-per-az-nat.json` | `./run.sh violations` - must be REFUSED, build fails if accepted |

This directory is kept as the documented home for the replacement procedure
below. Nothing under it is evaluated by any gate target.

## These numbers are not measurements

FIN-002 (`policy/finops.rego`) is **built and tested** but has **never been
exercised against a real Infracost run**. Infracost is not installed in this
environment, there is no `INFRACOST_API_KEY`, and `infracost breakdown` has
never executed against this repo. Both JSON files were hand-authored in the
real Infracost 0.10.x `breakdown` schema; their per-resource costs are
approximated from AWS public on-demand pricing, not fetched from a pricing API.

Two markers make that visible and are both load-bearing - do not drop either
without replacing the contents with real output:

- the `SYNTHETIC-` element of each filename, and
- the top-level `_synthetic` key inside each file, which states in prose that
  the file is hand-authored, which scenario it models, and which gate target
  asserts it.

Any dollar figure this repo produces today is illustrative. See `STATUS.md`.

## Replacing them with a real run

Once an `INFRACOST_API_KEY` exists, regenerate both scenarios - the same dev
plan with `single_nat_gateway` flipped in the tfvars between runs - write them
over the two paths in the table above, then drop the `SYNTHETIC-` filename
element and the `_synthetic` key:

```
infracost breakdown --path <terraform-plan.json> --format json \
  --out-file fixtures/conforming/perfile/fin-infracost-single-nat.json
infracost breakdown --path <terraform-plan.json> --format json \
  --out-file fixtures/violations/perfile/fin-infracost-per-az-nat.json
```

The gate needs no change: the conforming glob and the violations glob pick up
whatever is in those directories, and the violations target still fails the
build if the over-budget file is ever accepted. Update `STATUS.md` in the same
change - that is where the "never exercised against a real run" claim lives.

## Thresholds

`policy/budget.json` holds the per-environment ceilings and is the enforced
source: `run.sh` passes `--data policy`, which exposes its top-level keys as
`data.dev` / `data.prod`. Its `_comment` field carries the reasoning behind
dev = 250.0 and why prod = 900.0 is a placeholder no fixture exercises.
