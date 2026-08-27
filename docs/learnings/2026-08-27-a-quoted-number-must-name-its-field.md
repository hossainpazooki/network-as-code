# A quoted number must name its field

ts: 2026-08-27T15:12:00Z
commit: (none - uncommitted at capture time; repo HEAD 136f46f predates it)
session: https://claude.ai/code/session_014VvchHADG6EdNs3w8JrKY6
status: verified
fact: A tool's output usually carries several counts that are all plausibly "the number of resources". A comment or doc that quotes one of them under a different field's name is not wrong by a little - it is a claim about a field that has a different value, and it will read as correct to everyone who does not open the raw file, which is everyone.
basis: `policy/finops.rego`'s FIN-003 comment stated, from 2026-08-26, that `projects[].summary.totalDetectedResources` was "12, 14 and 14 on the successful runs". The measured files committed on 2026-08-27 show `totalDetectedResources` = 99, 107, 107. The 12/14/14 figures are real - they are `totalSupportedResources`, and the length of `breakdown.resources` - but they belong to a different key from the one the rule reads and the comment named. FIN-003's zero-detected leg compares against `totalDetectedResources`, so the comment was describing the rule's own input with the wrong numbers. Found by re-reading the committed files rather than the earlier session's summary; corrected in place with the wrong figure retained and labelled.
re-verify: cd gates && python -c "import json; d=json.load(open('fixtures/conforming/perfile/fin-infracost-dev-single-nat.json'))['projects'][0]; print('detected', d['summary']['totalDetectedResources'], '| supported', d['summary']['totalSupportedResources'], '| breakdown.resources', len(d['breakdown']['resources']))"

The generalisation: when a number is written down next to a tool, write the
key it came from beside it, and re-read it from the file rather than from the
session that produced it. Related:
[[2026-08-26-infracost-failed-module-load-costs-zero-and-exits-0]].
