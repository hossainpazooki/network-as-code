# The artifact carries the date; the brief only carries an intention

ts: 2026-08-27T15:11:00Z
commit: (none - uncommitted at capture time; repo HEAD 136f46f predates it)
session: https://claude.ai/code/session_014VvchHADG6EdNs3w8JrKY6
status: verified
fact: A session brief's date is when someone expected the work to happen, not when it happened. Generated artifacts carry their own timestamps - a tool's `timeGenerated`, a CI run's `created_at`, the shell's `date -u` - and those are the oracle for "when". A record that copies the brief's date into a document will be contradicted by the first artifact that sits next to it, and a hostile reader finds that contradiction before anything else.
basis: the 2026-08-27 session ran from a seed titled "2026-08-28". Fourteen occurrences of that date were written into STATUS.md, CLAUDE.md, gates/run.sh and PROVENANCE.md before the infracost run returned JSON stamped `timeGenerated` 2026-08-27T14:50:12Z - and GitHub had already stamped the session's own push at 2026-08-27T14:15:41Z. Every occurrence was corrected to the machine-true date before any file was committed; the JSON's timestamp is now the same date STATUS records for the measurement.
re-verify: cd gates && python -c "import json; print('fixture generated:', json.load(open('fixtures/conforming/perfile/fin-infracost-dev-single-nat.json'))['timeGenerated'][:10])" && printf 'STATUS records: ' && grep -oE 'DERIVATION \(2026-[0-9-]+' policy/budget.json | head -1 | grep -oE '2026-[0-9-]+'

The generalisation: dates are empirical numbers and get the same treatment as
every other number in this repo - recomputed from the raw source at the point
of claiming, never carried forward from a document. Related:
[[2026-08-27-a-claim-about-a-document-outlived-the-document]].
