# conftest --combine changes the input shape, not just the file count

ts: 2026-08-25T02:47:54Z
commit: (none - repository had zero commits at capture time; working tree of 2026-08-25)
session: https://claude.ai/code/session_01RKDcJkwv49bhi7kbKLscpb
status: verified
fact: `conftest test` evaluates ONE parsed file per policy evaluation, so a rule needing cross-file facts is inexpressible per-file. `--combine` wraps every input into a single LIST of `{path, contents}` objects. A rule written for combined mode matches nothing in per-file mode and vice versa, so the two must live in separate policy directories and be run as separate invocations.
basis: `../.tools/conftest.exe parse --combine fixtures/historical/kube/base/egress-common.yaml` printed `[` then `{ "path": "fixtures/historical/kube/base/egress-common.yaml", "contents": { ...` - a list of wrappers, where the per-file parse of the same file prints the bare document object.
re-verify: cd gates && ../.tools/conftest.exe parse --combine fixtures/historical/kube/base/egress-common.yaml | head -3

This is why the repo has both `gates/policy/` and `gates/policy/combined/`, and
why SEC-003 and FIN-001 live in the latter. Related:
[[2026-08-25-terraform-default-tags-is-provider-wide]].
