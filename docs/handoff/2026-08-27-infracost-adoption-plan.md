# Infracost adoption - PROPOSED, nothing below is built

Status: **PROPOSED 2026-08-27.** No step here has been executed. Nothing in
`STATUS.md` claims any of it. **F2 and F3 were ruled on by the author on
2026-08-27 and are closed** - see below. Step 1 is unblocked; nothing was
started, because execution is a separate session's work.

Claim ceiling for the whole of this, fixed in advance so no step can drift past
it: **"cost-delta gating demonstrated on pinned point-in-time estimates."**
Never "cost controlled". Never "live". The committed JSON is a measurement
taken once, on a dated tree, by a named tool version - it is not a statement
about what anything costs now.

## Why this is not already done

`terraform/iam.tf` sources three local modules:

```
module "builder_role"      { source = "../modules/iam/builder"      }
module "provisioner_role"  { source = "../modules/iam/provisioner"  }
module "pod_roles"         { source = "../modules/iam/pod"          }
```

`../modules/` resolves to a **sibling of `terraform/`** inside the vendored
subtree - the same level as `terraform/` and `kube/`. Those nine files were
never vendored, so `fixtures/historical/terraform/iam.tf` currently carries
three dangling module references. Infracost cannot evaluate the tree: on
2026-08-26 it failed the module load, priced nothing, and **exited 0** with
`totalMonthlyCost` `"0"` (this is the finding that produced FIN-003).

## What was verified on 2026-08-27, offline, before any of this was planned

The ref cited in `PROVENANCE.md` is reachable from a local archived clone that
carries the subtree's own `.git`. That made two checks possible:

1. **All nine files exist at the ref**, with these blob SHAs:

   | Path at ref `95df6ef` | git blob SHA-1 |
   |---|---|
   | `modules/iam/builder/main.tf` | `2c368a6197b10ef47eb5280748e8d5f72cc20001` |
   | `modules/iam/builder/outputs.tf` | `eee5bc372c48a9a732f0ed018e5c6750dc406117` |
   | `modules/iam/builder/variables.tf` | `1c78d329a17b0d4d6c4058ec25b525a2c403e7ae` |
   | `modules/iam/pod/main.tf` | `f9a155326304d43a828158ee39af83121b9aef47` |
   | `modules/iam/pod/outputs.tf` | `3e30c4a272d8d89a3130b9f7fd622acc91b9e220` |
   | `modules/iam/pod/variables.tf` | `c522009d3e50ee3282cd7e8390aa360425e4bf30` |
   | `modules/iam/provisioner/main.tf` | `c329e89dd94f57e8cd49b70f182f25ac2921b33e` |
   | `modules/iam/provisioner/outputs.tf` | `c27be4849b853de599a5efc5f2b42bdbc360eaf6` |
   | `modules/iam/provisioner/variables.tf` | `2f97ac56d0e810ff5cd9b7e256477e27b4bc54a2` |

2. **The 22 already-vendored files still equal the ref**, byte for byte:
   22 match, 0 differ, 0 absent. `PROVENANCE.md` states that ref-equality "was
   established once, at vendoring time, on 2026-08-24" and that the offline
   check proves only "unmodified since vendoring". That second, stronger claim
   has now been re-established once more, on 2026-08-27, and it is what makes
   vendoring nine more files from the same ref defensible rather than hopeful.

**Vendor from the ref, not from a working tree.** A local copy of a subtree can
lag the ref it cites, and a ledger built from that copy would prove "unmodified
since vendoring" while silently dropping "equal to the cited ref". Use
`git -C <archived-clone> show 95df6ef:modules/iam/<...>` for every file.

## F3 - where the nine files should live

**DECIDED 2026-08-27: Option A.** Extend `fixtures/historical/`, ledger
22 -> 31. Both options are kept below with their consequences, so the reason
survives the decision.

**Option A - extend `fixtures/historical/`, ledger 22 -> 31.**

- The paths preserve the source layout exactly: `modules/` becomes the third
  top-level directory of the same subtree, beside `terraform/` and `kube/`.
  This is not importing foreign material into the evidence tree; it is
  finishing an incomplete vendoring of one subtree at one ref.
- One ledger, one `PROVENANCE.md`, one tree-exactness check.
- Cost: it requires a sanctioned exception to hard rule 1 in `CLAUDE.md`
  ("never edit OR ADD anything under `gates/fixtures/historical/`"), and the
  tree-exactness guard must learn the nine new rows **in the same commit** or
  the guard fails the moment the files land.
- The honest reading is that the dangling `../modules/iam/*` references are an
  existing provenance defect - the subtree was vendored incompletely - and
  option A repairs it rather than bending the rule.

**Option B - a sibling `fixtures/vendored-modules/` with its own ledger.**

- Hard rule 1 stays absolute, with no exception to write down.
- Cost: provenance splits across two ledgers and two `PROVENANCE.md` files;
  `verify-provenance` must be taught about both, and its tree-exactness check
  duplicated. The source-repo path layout is broken, so `iam.tf`'s
  `../modules/iam/builder` no longer resolves by position - infracost would
  need the copy assembled into the right shape at run time anyway, which is
  the layout option A just stores directly.
- It also makes the evidence tree no longer a faithful subtree image, which is
  the property `PROVENANCE.md` currently rests on.

**Ruled: A.** The exception must be written into `STATUS.md` and `CLAUDE.md`
*before* the files land, naming the ref, the nine paths, and why this is a
completion of an incomplete vendoring rather than an edit of evidence. Hard
rule 1 keeps its force everywhere else; this is the one sanctioned exception
and it is spent once.

## Steps

### 1. Vendor the nine files (unblocked - F3 ruled A)

Extract each from the ref, write it under
`gates/fixtures/historical/modules/iam/`, append its row to
`BLOBSHAS.txt` and the `PROVENANCE.md` table, and extend the tree-exactness
check - all in one commit, because the guard fails on any unrecorded file and
would otherwise turn the build red between two commits.

Then, before anything else: `./run.sh gate`. Expect `HISTORICAL_EXPECTED` to
move. Nine new `.tf` files enter the per-file and terraform-combined loops, so
FIN-001 and possibly OBS/SEC counts change. **Do not tune a rule to hold 13.**
Measure the new number, record its composition in `run.sh` and `STATUS.md` the
way the current 13 is recorded, and state in the commit that the count moved
because the input grew, not because a rule changed.

### 2. Run Infracost locally, once, and commit the output

Directory mode only: `infracost breakdown --path <dir>` parses HCL itself and
needs no AWS credentials. **Never** `--path <terraform-plan.json>` - that
requires `terraform plan` and therefore credentials, which the spec forbids.

**Run against a COPY of the tree, never the evidence tree.** On 2026-08-26 a
run inside `fixtures/historical/terraform/` wrote an 822-file module cache into
it and every blob SHA still matched. The tree-exactness guard now catches that,
but the correct habit is not to create the situation.

Commit each breakdown JSON with a provenance block recording: tool version
(v0.10.45), the exact command, the input tree's identity (the ref plus the
ledger's own hash), the date, and the currency. Drop the `SYNTHETIC-` filename
element and the `_synthetic` marker key - they are measurements now. Label them
point-in-time estimates in the filename or a sibling README, not "costs".

### 3. Re-derive `budget.json` (F2 - DECIDED)

Measured 2026-08-26, recorded in `STATUS.md`, not in any fixture:

| Scenario | Measured monthly |
|---|---|
| dev, single NAT | 594.42 |
| dev, per-AZ NAT | 660.12 |
| prod | 853.40 |

Current `budget.json` has dev = 250, ~2.4x below its own baseline, derived from
the synthetic NAT-only figures.

**DECIDED 2026-08-27: dev = 625.0, prod = 900.0.**

| Ceiling | Value | Against measured | Verdict |
|---|---|---|---|
| dev | 625.00 | single-NAT 594.42, +5.1% headroom | PASS |
| dev | 625.00 | per-AZ 660.12, 5.3% under | REFUSE |
| prod | 900.00 | 853.40, +5.5% headroom | PASS |

625 sits near the midpoint of the interval that preserves the rule's intent,
so neither verdict is knife-edge against ordinary price drift - a ceiling one
percent above its own baseline turns the build red for a non-reason, and a
ceiling one percent below the violating case makes the NEGATIVE CONTROL the
fragile one instead. Prod keeps the number 900 but stops being a placeholder:
`STATUS.md` must record it as derived from measured 853.40 at +5.5%. Same
value, honest provenance - it currently sits there by coincidence.

Both fixtures and `fin002_embedded_budget` must move with these;
`test_fin002_embedded_budget_matches_budget_json` fails if only one does.

### 4. FIN-002 schema-drift guard (no decision needed)

FIN-002 reads `projects[].name` and `projects[].breakdown.totalMonthlyCost`,
which are **v0.10.x keys**. Infracost v2.x renamed them to
`projects[].project_name` and `summary.total_monthly_cost`. Against a v2
breakdown FIN-002 matches nothing and silently approves every cost - the
FIN-003 failure mode with a different cause, and the more dangerous one because
upgrading the tool is a routine act that would trigger it.

Add a clause refusing a breakdown in which **no project matches the expected
shape**. Ships, like every rule here, with: a negative control under
`fixtures/violations/perfile/` (a v2-shaped breakdown), unit tests, and a
mutation proof that deleting the clause turns the build red. Note that
`./run.sh coverage`'s clause pass now enforces the negative control
automatically - a new clause with no fixture fails the build on its own.

## What this does not become

Live `terraform plan`/`apply` gating. Enforcement over anything running. A
claim that costs are controlled. An Infracost call in CI - the path chosen and
recorded in `STATUS.md` is local-run-committed-output, and CI evaluates only
committed bytes, with zero credentials and zero spend.
