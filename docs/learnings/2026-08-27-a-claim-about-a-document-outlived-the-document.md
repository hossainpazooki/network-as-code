# A claim about a document is not a claim the document can defend

ts: 2026-08-27T00:01:00Z
commit: (none - uncommitted at capture time; repo HEAD a626b58 predates it)
session: https://claude.ai/code/session_014VvchHADG6EdNs3w8JrKY6
status: verified
fact: A note recording that some OTHER file is stale is a second-hand claim, and it decays the same way any other unverified claim does - except worse, because it looks like diligence. Its subject is a file nobody now needs to open: the note has already told the reader what is in there. Handoff briefs then carry it forward as a task, and the task's premise is never re-derived because a written status stands in for the document itself.
basis: from 2026-08-24, `STATUS.md` carried "Known stale doc, deliberately not touched: gates/docs/parse-shape.md still lists FIN-001 under policy/ per-file rules and says policy/combined/ holds 'SEC-003 only'." Neither half was true. `git show 4319ab2:gates/docs/parse-shape.md` - the file's only commit before 2026-08-27 - reads "`policy/combined/` - cross-file rules (SEC-003, and FIN-001)" at line 138, and carries a paragraph arguing why FIN-001 must live in combined mode. `grep -c "SEC-003 only"` against that same blob returns 0; the string existed in exactly one place in the repository, inside the note making the accusation. The note survived nine days, a handoff brief, and a session seed that promoted it to a task ("fix the two stale lines"). Re-deriving the document's claims from the tree instead of patching the two named lines found two REAL errors, neither of them the alleged ones: FIN-003 had shipped on 2026-08-26 without being added to the per-file rule set, and the "cosmetic quirk" bullet about escaping was wrong in a way that would produce a never-firing rule (see the sibling entry).
re-verify: cd ~/dev/network-as-code && git show 4319ab2:gates/docs/parse-shape.md | grep -n "combined/. - cross-file" && echo "--- occurrences of the alleged string at that commit:" && git show 4319ab2:gates/docs/parse-shape.md | grep -c "SEC-003 only"

The generalisation: when a status note says another file is wrong, the correct
response is never to patch the lines the note names - it is to re-derive the
file's claims from the tree and let the note stand or fall with them. The note
is a claim; the tree is the evidence. This is the doc-level form of the rule
already applied to numbers ("recompute from the raw source at the point of
claiming"), and it deserves the same reflex. Related:
[[2026-08-27-a-serialisation-artifact-is-not-a-property-of-the-value]] and
[[2026-08-27-a-gate-step-with-no-ci-job-is-a-local-opinion]], both found by the
same sweep and neither by reading the note.
