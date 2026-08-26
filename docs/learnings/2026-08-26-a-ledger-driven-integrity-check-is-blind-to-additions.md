# A ledger-driven integrity check is blind to files that were added

ts: 2026-08-26T21:31:12Z
commit: (none - this change was uncommitted at capture time; repo HEAD bbcd6a3 predates it)
session: https://claude.ai/code/session_01A1FzkjBaAADiWxTmdjrBGg
status: verified
fact: An integrity check that iterates a manifest and hashes each recorded path proves only that RECORDED files are unmodified. It cannot see files that were ADDED, because nothing in the loop ever reads the directory. The check reports full success - "22 files verified" - over a tree that has been contaminated. Detecting addition requires comparing the manifest against the actual file set in both directions, which is a different operation from hashing, not a stronger version of it.
basis: on 2026-08-26 an `infracost breakdown` run executed inside gates/fixtures/historical/terraform wrote a 22MB, 822-file `.infracost/terraform_modules/` cache into that read-only evidence tree. `./run.sh verify-provenance` passed and printed "22 files verified against PROVENANCE.md"; `git diff` over the 22 vendored files was empty, so every blob SHA genuinely still matched. The contamination surfaced only because `./run.sh historical` asserts an exact finding count, which moved 13 -> 100 when the downloaded third-party modules tripped OBS-001 25 times. Had the added files tripped no rule, nothing would have objected. The check was then extended to assert set equality in both directions, and mutation-tested: one added file under the tree makes it exit 1 naming that file, and removing the file returns it to exit 0.
re-verify: cd gates && mkdir -p fixtures/historical/terraform/.probecache && echo x > fixtures/historical/terraform/.probecache/m.tf && ./run.sh verify-provenance >/dev/null 2>&1; echo "with extra file: exit=$?"; rm -rf fixtures/historical/terraform/.probecache; ./run.sh verify-provenance >/dev/null 2>&1; echo "clean: exit=$?"

The generalisation: any manifest-driven verifier answers "is what I recorded
still true?", never "is what is here still only what I recorded?". Both
questions need asking, and only the second one catches contamination. The
exact-count assertion in `./run.sh historical` caught this by luck, which is
not a control. Related:
[[2026-08-25-conftest-exit-code-cannot-distinguish-error-from-refusal]].
