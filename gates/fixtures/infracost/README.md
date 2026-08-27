# fixtures/infracost/ - FIN-002 / FIN-003 fixtures: what they are, how they were made

**No JSON lives here.** The breakdowns sit in the directories `run.sh` globs,
because a fixture CI never reads is not a control. This directory holds the
procedure and the provenance story.

| Scenario | File | Kind | Asserted by |
|---|---|---|---|
| dev, `single_nat_gateway = true` (as shipped), `totalMonthlyCost` **594.416** | `fixtures/conforming/perfile/fin-infracost-dev-single-nat.json` | **measured** | `./run.sh conforming` - must PASS under dev 625.0 |
| dev, one NAT per AZ (`single_nat_gateway` overridden to false), **660.116** | `fixtures/violations/perfile/fin-infracost-dev-per-az-nat.json` | **measured** | `./run.sh violations` - must be REFUSED by FIN-002 |
| prod, as shipped, **853.404** | `fixtures/conforming/perfile/fin-infracost-prod.json` | **measured** | `./run.sh conforming` - must PASS under prod 900.0 |
| failed module load, `totalMonthlyCost` "0", zero resources | `fixtures/violations/perfile/fin-SYNTHETIC-infracost-broken-module-load.json` | hand-authored reconstruction | `./run.sh violations` - must be REFUSED by FIN-003 |

## What "measured" means here, and what it does not

The three measured files are the real output of `infracost breakdown`, run
**once**, **locally**, on 2026-08-27, with Infracost **v0.10.45** in directory
(HCL) mode against a copy of the vendored root module. Each carries a
`_provenance` block as its first key recording the exact command, the tool
version, the input tree's identity (source ref `95df6ef` plus the sha256 of
`BLOBSHAS.txt`), the generation timestamp, and the currency. Remove that one
key and the remainder is the breakdown byte-for-byte as the tool wrote it.

They are **point-in-time estimates**: the prices are what the Infracost Cloud
Pricing API returned at `timeGenerated`. Nothing in this repo re-prices them,
nothing running was measured, and CI never calls Infracost - it evaluates the
committed bytes with conftest, deterministically, with no credential and no
network. The claim this supports, and the only one, is:

> cost-delta gating demonstrated on pinned point-in-time estimates.

Not "cost controlled". Not "live".

## The generation / evaluation split

| | Generation | Evaluation |
|---|---|---|
| Where | a developer machine, once | CI, every push and PR |
| Tool | Infracost v0.10.45 | conftest 0.69.0 / OPA 1.19.1 |
| Needs | an Infracost API key (pricing lookups; **no AWS credentials** - directory mode parses HCL itself) | nothing |
| Network | Infracost Cloud Pricing API | none |
| Input | a copy of `fixtures/historical/{terraform,modules}` | the committed JSON |
| Output | the three JSON files above | a verdict |

The first column is the only place a credential exists, and it never appears
in this repository or its CI.

## The two things the first real run taught (2026-08-26)

- **A failed parse is silent.** Against the 22-file tree of the time, infracost
  could not resolve `../modules/iam/*`, priced nothing, reported
  `totalMonthlyCost` "0" and exited 0. FIN-003 exists to refuse exactly that;
  the nine missing files were vendored on 2026-08-27 (the one sanctioned
  exception to the no-additions rule, recorded in `STATUS.md`).
- **The schema is version-bound and the binding is invisible.** FIN-002 reads
  v0.10 paths; v2 renamed them, against which FIN-002 binds nothing and approves
  everything. The `_provenance.tool` field in each measured file is the pin;
  a policy-side guard is the next change (see `STATUS.md`).

## Regenerating

Directory mode only. **Never `--path <terraform-plan.json>`**: producing a plan
means `terraform init` + `plan`, which needs AWS credentials, which this repo
forbids. And **never run inside `fixtures/historical/`**: infracost writes a
`.infracost/terraform_modules/` cache into its working tree (822 files on
2026-08-26; every blob SHA still matched; the tree-exactness guard now catches
it, and the habit is not to create it).

```
COPY=$(mktemp -d)
cp -R gates/fixtures/historical/terraform gates/fixtures/historical/modules "$COPY/"
cd "$COPY"
infracost breakdown --path terraform --terraform-var-file envs/dev.tfvars  --project-name dev  --format json --out-file dev-single-nat.json
infracost breakdown --path terraform --terraform-var-file envs/dev.tfvars  --terraform-var single_nat_gateway=false --project-name dev --format json --out-file dev-per-az-nat.json
infracost breakdown --path terraform --terraform-var-file envs/prod.tfvars --project-name prod --format json --out-file prod.json
rm -rf "$COPY"
```

Then prepend a `_provenance` block in the shape the existing files use, drop
nothing else, and - because the figures are claims - update `STATUS.md` and
re-derive `policy/budget.json`'s ceilings in the same change. If the new totals
differ materially from the recorded ones, determine whether the tree, the tool
version or the pricing moved before committing anything.

## Ceilings

`policy/budget.json` is the enforced source (`--data policy`). dev = 625.0 sits
near the midpoint of (594.416, 660.116) so that the shipped topology passes with
5.1% headroom and the per-AZ topology is refused with 5.3% margin. prod = 900.0
is measured 853.404 plus 5.5% - the same number the file carried as a
placeholder, now derived. The `_comment` in that file holds the full reasoning.
