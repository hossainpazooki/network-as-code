# PROVENANCE - vendored historical config

These files are verbatim copies of infrastructure I designed, operated, and
then tore down. They are evidence, not scaffolding. **Do not edit them.**
Several gate rules deliberately flag findings in these files; that is the
self-audit, and fixing the fixtures would destroy it.

## Source

| Field | Value |
|---|---|
| Source | The platform-infrastructure subtree of my local monorepo (repository name withheld) |
| Ref | `95df6efd8be92dc589e2cbd0124c79b78922dade` |
| Commit date | 2026-08-03T16:51:28Z |
| Commit subject | docs: mark infra decommissioned, record teardown and residuals |
| Vendored on | 2026-08-24 (22 files); completed 2026-08-27 with the nine `modules/iam/**` files `terraform/iam.tf` sources, from the same ref - the one sanctioned exception to the no-additions rule, recorded in `STATUS.md` |
| Method | fetched from that subtree's upstream remote at the ref above, then blob-verified (below) |

The subtree's own paths are recorded below (`terraform/…`, `kube/…`); the
repository it lives in is deliberately not named here.

## Integrity

Each row is the git blob SHA-1 of the file as it was vendored. Recompute
any row with `git hash-object <path>` and compare — `./run.sh verify-provenance`
does exactly that for all 31 files at once.

What this proves OFFLINE is exactly one thing: the 31 files are **unmodified
since vendoring**. It does NOT re-check them against the upstream ref - that
would need the network and the source repo, neither of which the gate has. The
equality with the ref was established at vendoring time, on 2026-08-24, and
re-established offline on 2026-08-27 by comparing every row against `git ls-tree`
at the ref in an archived clone (22 match, 0 differ); the nine 2026-08-27
additions were extracted from that same ref and hash-checked on write.

Nor does it make them **attributable**: nothing here proves this configuration
was mine to operate. That is something I supply directly - deliberately, since
the source repository is not named.

Verify every row at once:

```sh
./run.sh verify-provenance
```

| Path (in source repo) | git blob SHA-1 |
| `kube/base/egress-common.yaml` | `9b7a29a56a7477b447e3207f6507f5566ebf292d` |
| `kube/base/kustomization.yaml` | `504eeb6ca72c0e48281818678f84b216ef220a83` |
| `kube/base/namespace.yaml` | `277a72beca0a458ef4f43d460fd953274b2c1454` |
| `kube/base/regulatory-workbench-deployment.yaml` | `19cdeabd144a499df711a31425eb3f0a58af3d75` |
| `kube/base/regulatory-workbench-service.yaml` | `e1cd93ea0de3d4dade0bb83f42c04971e2e388d5` |
| `kube/overlays/dev/egress-app.yaml` | `0114b740c5ed689bd2c05341bc2c888c7971a024` |
| `kube/overlays/dev/ingress.yaml` | `fe1f6038ccf6080bd4e085f02bfcaf25cf4accee` |
| `kube/overlays/dev/kustomization.yaml` | `04d508963d648055c7028367fb7ecd8276ca9073` |
| `terraform/ecr.tf` | `32da1322e6e4d6a4cb0633fb4b2ba18566064fcd` |
| `terraform/eks.tf` | `71511674c44abafda2704c1e576947a9a3dabcca` |
| `terraform/elasticache.tf` | `344863fa2f14d1d1bee995e72fbd3c0695ae06d0` |
| `terraform/envs/dev.tfvars` | `3cc181a844e1b97b13d5369d88a45daaa126b776` |
| `terraform/envs/prod.tfvars` | `13fe0a9087d39de6aec4a738fc910bc3dcb71d95` |
| `terraform/github-variables.tf` | `eee23af5b370e3b642fe4a2fdd8b9636ad0df67f` |
| `terraform/iam.tf` | `a430cda214491a0b9458fb95b6cd0a8415381c6f` |
| `terraform/outputs.tf` | `2b4e692405d815759bced6ac817cf221836ec5f9` |
| `terraform/outputs-iam.tf` | `dcf616f01fd54aff5cec22c6f157e484adf6fc13` |
| `terraform/rds.tf` | `ab870e4b203d054b82170cc5fcd352f2882aa28c` |
| `terraform/secrets.tf` | `29a030e6fabd1e1dfd025055938988b7d46ae081` |
| `terraform/variables.tf` | `4a92411ea4528f0dcbdfba6d64204b40eec08cfc` |
| `terraform/versions.tf` | `c63abd02bfb7a978cf41cbc4113e62d40d4b96c2` |
| `terraform/vpc.tf` | `2ac14906a84db64eb7bfa12665ec390e3f4ed718` |
| `modules/iam/builder/main.tf` | `2c368a6197b10ef47eb5280748e8d5f72cc20001` |
| `modules/iam/builder/outputs.tf` | `eee5bc372c48a9a732f0ed018e5c6750dc406117` |
| `modules/iam/builder/variables.tf` | `1c78d329a17b0d4d6c4058ec25b525a2c403e7ae` |
| `modules/iam/pod/main.tf` | `f9a155326304d43a828158ee39af83121b9aef47` |
| `modules/iam/pod/outputs.tf` | `3e30c4a272d8d89a3130b9f7fd622acc91b9e220` |
| `modules/iam/pod/variables.tf` | `c522009d3e50ee3282cd7e8390aa360425e4bf30` |
| `modules/iam/provisioner/main.tf` | `c329e89dd94f57e8cd49b70f182f25ac2921b33e` |
| `modules/iam/provisioner/outputs.tf` | `c27be4849b853de599a5efc5f2b42bdbc360eaf6` |
| `modules/iam/provisioner/variables.tf` | `2f97ac56d0e810ff5cd9b7e256477e27b4bc54a2` |
