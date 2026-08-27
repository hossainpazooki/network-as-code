# Handoff index

Pointers only, never evidence. Entries are immutable once written: a later
session writes a new dated entry rather than editing an older one.

| Date | Brief | Describes commit | One-line |
|---|---|---|---|
| 2026-08-25 | [network-as-code gates, first build](2026-08-25-network-as-code-gates-first-build.md) | none — zero commits, untracked working tree | Gate green locally (8 rule IDs, 17 negative controls, 13/13 self-audit, 22/22 provenance); CI written but never executed, initial commit not yet made. |
| 2026-08-27 | [network-as-code ship: claim closed, FIN-002 measured, exception spent](2026-08-27-network-as-code-ship.md) | `ae2a05c` (merge of PR #2) | PR #1 blocked a merge on the failing `conforming` check; 31-file root module vendored under the one sanctioned exception; FIN-002 reads measured breakdowns with derived ceilings; FIN-004 added; 15/15 self-audit, 16/16 clauses, six-job CI green. |
