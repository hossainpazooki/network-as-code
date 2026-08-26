# opa test auto-loads JSON as data; conftest requires an explicit relative --data root

ts: 2026-08-25T02:48:35Z
commit: (none - repository had zero commits at capture time; working tree of 2026-08-25)
session: https://claude.ai/code/session_01RKDcJkwv49bhi7kbKLscpb
status: verified
fact: `opa test policy <testdir>` automatically loads any `.json` under the policy directory as `data`, so a unit test can assert against it with no flag at all. `conftest test --policy policy` does NOT: the same file stays invisible until an explicit `--data policy` root is passed, and that root must be RELATIVE (an absolute path is not resolved the same way under Git Bash on Windows). The file name is never part of the namespace, so `policy/budget.json`'s top-level keys land at `data.dev` / `data.prod`.
basis: `opa test policy <tmpdir>` with a test asserting `data.dev.monthly_usd_max == 250` printed `PASS: 1/1`. The same static reference under conftest WITHOUT `--data` printed `1 test, 1 passed, 0 warnings, 0 failures` (the rule was undefined and never fired); WITH `--data policy` it printed `FAIL ... data.dev={"monthly_usd_max": 250.0}`.
re-verify: cd gates && ../.tools/opa.exe test policy tests --verbose 2>&1 | grep -i budget

Why it matters: without the flag, an external config file is documentation sitting
beside a hand-synced copy inside the rules, and the two drift silently. With the
flag, PLUS a unit test asserting the embedded fallback equals the file, the sync
becomes gated rather than hoped for. Note the trap in
[[2026-08-25-dynamic-data-reference-is-a-rego-recursion-error]]: the lookup must
use static paths, so "read the budget for env X" cannot be written generically.
