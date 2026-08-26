# conftest's exit code cannot distinguish a policy refusal from a tool error

ts: 2026-08-25T02:48:14Z
commit: (none - repository had zero commits at capture time; working tree of 2026-08-25)
session: https://claude.ai/code/session_01RKDcJkwv49bhi7kbKLscpb
status: verified
fact: `conftest test` exits 1 BOTH when a policy refuses an input and when conftest cannot evaluate the input at all (empty directory, unknown parser, missing file). A negative-control loop asserting "non-zero exit means refused" therefore counts an empty directory, or a file with no known parser, as a PASSING control - which makes the negative control vacuous exactly where it is load-bearing. Count actual deny messages from `-o json` instead, and treat a tool error as a third outcome that hard-fails, distinct from both accept and refuse.
basis: `conftest test --combine <empty dir> --policy policy/combined --all-namespaces` printed `Error: running test: parse files: no files found` and exited 1. `conftest test fixtures/violations/perfile/netpol-wide-ipblock.yaml --policy policy --data policy --all-namespaces` printed 1 FAIL line and exited 1. Identical exit codes, opposite meanings.
re-verify: d=$(mktemp -d); (cd gates && ../.tools/conftest.exe test --combine "$d" --policy policy/combined --all-namespaces >/dev/null 2>&1; echo "tool-error exit=$?")

This shipped as a live defect in `gates/run.sh` and was found by an adversarial
review, not by the gate itself - the gate was green throughout. Fixed with
`deny_count()` / `assert_refused()` in `gates/run.sh`, and mutation-proven: an
empty combined directory and a stray `.txt` both now fail `./run.sh violations`,
while the clean tree stays green.
