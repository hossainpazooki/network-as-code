# A gate step with no CI job is a local opinion, not a gate

ts: 2026-08-27T00:00:00Z
commit: (none - uncommitted at capture time; repo HEAD a626b58 predates it)
session: https://claude.ai/code/session_014VvchHADG6EdNs3w8JrKY6
status: verified
fact: A build script's aggregate target and a CI workflow's job list are two independent enumerations of the same sequence, and nothing keeps them in sync. A step can be added to the local aggregate and never gain a job, at which point its assertion runs only where the author happens to run it. The failure is silent in both directions: CI stays green because the steps that DO have jobs still pass, and the local run stays green because the step passes there. Only a diff of the two enumerations shows the gap.
basis: `gates/run.sh`'s `t_gate()` has called `t_coverage` since 2026-08-24, when coverage was added to close the SEC-001 uncovered-clause gap. `.github/workflows/gate.yml` defined five jobs - verify-provenance, unit, conforming, violations, historical - and none of them ran `./run.sh coverage`. So from 2026-08-24 to 2026-08-27 the assertion "every declared rule ID is emitted by some refusing fixture" was enforced on one Windows laptop and nowhere else; a rule pushed with no negative control would have merged green, because the other fixtures were still refused and no job checked the set. Run `33016125195`, cited in README and STATUS as proof the gate works in CI, never evaluated it. Four documents asserted the opposite, in three different phrasings ("one job per target" twice, "the same five are DEFINED as separate jobs" once, plus a `./run.sh gate` comment that omitted coverage from the step list). Fixed by adding the sixth job with `needs: violations`, re-pointing `historical` at `needs: coverage`, and correcting all four claim sites in the same commit. Mutation-proven: appending a deny clause with a fresh rule ID and no fixture makes `./run.sh coverage` exit 1 naming that ID; the clean tree exits 0.
re-verify: cd ~/dev/network-as-code && sed -n '/^t_gate() {/,/^}/p' gates/run.sh | sed -n 's/^[[:space:]]*t_\([a-z_]*\)$/\1/p' | tr '_' '-' | sort > /tmp/steps.txt && python -c "import yaml;print(chr(10).join(sorted(yaml.safe_load(open('.github/workflows/gate.yml'))['jobs'])))" | tr -d '\r' > /tmp/jobs.txt && diff /tmp/steps.txt /tmp/jobs.txt && echo "OK: every gate step has a CI job"

The generalisation: "the gate is green in CI" is a claim about the jobs that
ran, never about the checks that exist. Any repo with a local aggregate target
and a CI job list needs the two enumerated and diffed by something, or the
aggregate slowly becomes the more thorough of the two and nobody notices which.
This is the same shape as the `|| true` Checkov steps this repo was built to
correct, and as FIN-002's refusing fixture sitting outside every `run.sh` glob:
a check that cannot fail the build is not a check. Third instance. Related:
[[2026-08-25-conftest-exit-code-cannot-distinguish-error-from-refusal]].
