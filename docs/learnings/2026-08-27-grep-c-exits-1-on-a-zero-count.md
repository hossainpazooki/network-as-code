# grep -c exits 1 on a zero count, and `set -e` turns that into a silent stop

ts: 2026-08-27T00:03:00Z
commit: (none - uncommitted at capture time; repo HEAD a626b58 predates it)
session: https://claude.ai/code/session_014VvchHADG6EdNs3w8JrKY6
status: verified
fact: `grep -c` reports a count on stdout AND an exit status describing whether anything matched: 0 when the count is positive, 1 when the count is zero. So `n=$(grep -c PATTERN file)` is a command substitution that fails whenever the honest answer is zero. Under `set -e` the shell exits at that assignment - with no message, having printed every successful line before it - which reads as the loop finishing rather than the loop dying. Counting is the one job `grep -c` cannot be trusted with in a `set -e` script, because a legitimate zero and a failure share one channel.
basis: while building `t_clause_coverage` in `gates/run.sh`, the pass reported 13 of 15 clauses covered and exited 1 with an empty stderr. The 14th clause is the only deny body in `policy/combined/finops_combined.rego`; after excising it the file contains zero clauses, so the post-mutation sanity check `after=$(grep -cE '^deny contains msg if' "$target")` printed 0 and exited 1, and `set -eu` ended the script mid-loop. The 13 lines already printed made it look like a completed run with a failing verdict, and the guard that would have reported a real problem never ran. Diagnosed by re-running the combined-file iteration in isolation under `sh -c 'set -eu; ...'`, where it stopped at the same assignment. Fixed with `awk '/pattern/{n++} END{print n+0}'`, which exits 0 whatever the count. `|| true` would also have worked and is banned in this repo - the `|| true` Checkov steps in the audited platform are the reason this repo exists - so the fix had to be a command that does not need its exit code suppressed.
re-verify: cd ~/dev/network-as-code && printf 'nothing here\n' > /tmp/probe.txt; sh -c 'set -eu; n=$(grep -c ABSENT /tmp/probe.txt); echo "reached: n=$n"'; echo "grep form exit=$?"; sh -c 'set -eu; n=$(awk "/ABSENT/{c++} END{print c+0}" /tmp/probe.txt); echo "reached: n=$n"'; echo "awk form exit=$?"; rm -f /tmp/probe.txt

The generalisation: this is the repo's own defect family wearing different
clothes. `conftest` exits 1 for "policy refused" and for "could not read the
input"; Infracost exits 0 for "priced nothing" and for "nothing to price";
`grep -c` exits 1 for "no matches" and, indistinguishably, tells the caller the
count it asked for. Any tool that answers a question on stdout and a DIFFERENT
question through its exit status will eventually be read as answering the
wrong one - and `set -e` converts that misreading into a silent truncation
rather than an error. Related:
[[2026-08-25-conftest-exit-code-cannot-distinguish-error-from-refusal]] and
[[2026-08-26-infracost-failed-module-load-costs-zero-and-exits-0]].
