#!/bin/sh
# Gate runner. POSIX sh: identical behaviour in Git Bash (Windows) and Linux CI.
# Usage: ./run.sh <target>
#   unit | conforming | violations | combined | historical | gate
#   parse | verify-provenance | demo | tools
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
cd "$HERE"

# ---------------------------------------------------------------- toolchain
CONFTEST_VERSION=0.69.0
OPA_VERSION=1.19.1

find_tool() {
	name=$1
	for c in "../.tools/$name.exe" "../.tools/$name" "$(command -v "$name" 2>/dev/null || true)"; do
		[ -n "$c" ] && [ -x "$c" ] && { echo "$c"; return 0; }
	done
	echo "FATAL: $name not found. Run './run.sh tools' or install $name." >&2
	exit 127
}

CONFTEST=$(find_tool conftest)
OPA=$(find_tool opa)

# Expected count of findings in the vendored historical config.
# Changing this number is a claim: update STATUS.md in the same commit.
# Measured 2026-08-24, composition (see STATUS.md):
#   per-file (conftest test $HIST --policy policy)            -> 4
#     1 x OBS-001 (module.vpc, no flow logs)      -> terraform/vpc.tf
#     3 x SEC-002 (egress-common.yaml ipBlocks)   -> kube/base/
#   combined over kube/      (--policy policy/combined)       -> 1
#     1 x SEC-003 (no default-deny Ingress)
#   combined over terraform/ (--policy policy/combined)       -> 8
#     8 x FIN-001 (ecr 1, elasticache 3, rds sg 1, secrets 3)
# FIN-001 moved from per-file to combined mode on 2026-08-24 (a correctness
# fix, not a re-tune): provider default_tags applies to the whole root module,
# so a per-file rule reported Environment missing when versions.tf declares it.
# The COUNT is unchanged at 8 - App is genuinely absent on all 8 resources -
# but the messages now name only the tags that are really missing.
HISTORICAL_EXPECTED=${HISTORICAL_EXPECTED:-13}

POLICY=policy
POLICY_COMBINED=policy/combined
# Data root for conftest. policy/budget.json sits at the root of this tree, so
# its top-level keys are exposed as data.dev / data.prod (the file name is
# never part of the namespace). This flag is what makes budget.json the
# ENFORCED source for FIN-002 rather than documentation next to a hand-synced
# copy. Must stay RELATIVE: an absolute path is not resolved the same way.
DATA=policy
HIST=fixtures/historical
# Scratch root for the clause-coverage mutation pass. Matches the *.tmp rule in
# .gitignore. Lives under gates/ on purpose: conftest's --data root must stay
# RELATIVE (see the DATA note above), so the mutated policy tree cannot be put
# in the system temp directory without changing how budget.json resolves.
CLAUSE_TMP=.clausecov.tmp

# ------------------------------------------------------------------ helpers
say() { printf '\n=== %s ===\n' "$1"; }

# Count deny messages by asking conftest for machine-readable output.
count_failures() { # <json output on stdin>
	python -c 'import json,sys; d=json.load(sys.stdin); print(sum(len(r.get("failures") or []) for r in d))'
}

# How many deny messages did conftest actually emit for this input?
# Echoes an integer, or the literal string ERR when conftest could not evaluate
# the input at all (empty directory, unknown parser, missing file).
#
# A TOOL ERROR IS NOT A REFUSAL. conftest exits 1 both when a policy refuses an
# input and when it fails to read one, so an exit-code-only check would count
# an empty directory as a passing negative control - which would make the whole
# methodology vacuous. Everything below asks this function, never $?.
deny_count() { # <conftest argv...>
	out=$("$@" -o json 2>/dev/null) || true
	printf '%s' "$out" | python -c 'import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    print("ERR"); sys.exit(0)
if not isinstance(d, list) or not d:
    print("ERR"); sys.exit(0)
print(sum(len(r.get("failures") or []) for r in d))'
}

# Deny count for EVERY negative control, one line each: "<label> <count>".
#
# PER-FIXTURE, never a loop total. A total can hold steady while one fixture
# loses a finding and another gains one, so a clause that stopped mattering
# would read as still mattering - the same aggregate-masking shape the
# per-class vacuity guard already had to kill once in t_violations.
#
# Labels contain no spaces (they are repo-relative fixture paths), so a plain
# space separates the fields and awk's default splitting reads them back.
# Prints PARSE-ERROR for any input conftest could not evaluate, which the
# caller must treat as failure - never as "count unchanged".
clause_fixture_counts() { # <policy-root>
	_root=$1
	"$CONFTEST" test fixtures/violations/perfile/* --policy "$_root" --data "$_root" --all-namespaces -o json 2>/dev/null | python -c 'import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    print("PARSE-ERROR perfile"); sys.exit(0)
if not isinstance(d, list) or not d:
    print("PARSE-ERROR perfile"); sys.exit(0)
for r in d:
    print("%s %d" % (r.get("filename") or "?", len(r.get("failures") or [])))'
	for _d in fixtures/violations/combined/*/; do
		[ -d "$_d" ] || continue
		"$CONFTEST" test --combine "$_d" --policy "$_root/combined" --data "$_root" --all-namespaces -o json 2>/dev/null | python -c 'import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    print("PARSE-ERROR " + sys.argv[1]); sys.exit(0)
if not isinstance(d, list) or not d:
    print("PARSE-ERROR " + sys.argv[1]); sys.exit(0)
print("%s %d" % (sys.argv[1], sum(len(r.get("failures") or []) for r in d)))' "$_d"
	done
}

# A violation fixture must be refused BY A POLICY, with at least one deny.
assert_refused() { # <label> <conftest argv...>
	label=$1
	shift
	c=$(deny_count "$@")
	case "$c" in
	ERR)
		echo "TOOL ERROR on $label - conftest could not evaluate it. A tool error is not a refusal." >&2
		exit 1
		;;
	0)
		echo "NEGATIVE CONTROL FAILED: $label was ACCEPTED but must be refused" >&2
		exit 1
		;;
	*)
		echo "refused ok ($c deny): $label"
		;;
	esac
}

# Print conftest's human-readable output for an input we have ALREADY counted.
# Tolerates conftest's exit 1 only because $2 proves the non-zero exit came
# from real deny messages - this is what replaces '|| true'.
show_with_count() { # <count> <conftest argv...>
	expected=$1
	shift
	"$@" || [ "$expected" -gt 0 ]
}

# ------------------------------------------------------------------ targets
t_tools() {
	mkdir -p ../.tools
	echo "conftest $CONFTEST_VERSION / opa $OPA_VERSION expected."
	echo "Windows: binaries are vendored into ../.tools/ (gitignored)."
	echo "Linux/CI: the workflow installs the pinned versions onto PATH."
	"$CONFTEST" --version
	"$OPA" version | head -2
}

t_unit() {
	say "opa test (unit)"
	"$OPA" test "$POLICY" tests --verbose
}

t_conforming() {
	say "conforming fixtures must PASS (per-file)"
	"$CONFTEST" test fixtures/conforming/perfile --policy "$POLICY" --data "$DATA" --all-namespaces
	say "conforming fixtures must PASS (combined)"
	for d in fixtures/conforming/combined/*/; do
		[ -d "$d" ] || continue
		echo "-- $d"
		"$CONFTEST" test --combine "$d" --policy "$POLICY_COMBINED" --data "$DATA" --all-namespaces
	done
}

# The core methodology: a violation fixture that PASSES is a build failure.
t_violations() {
	say "violation fixtures must each be REFUSED (per-file)"
	np=0
	for f in fixtures/violations/perfile/*; do
		[ -f "$f" ] || continue
		np=$((np + 1))
		assert_refused "$f" "$CONFTEST" test "$f" --policy "$POLICY" --data "$DATA" --all-namespaces
	done
	say "violation fixtures must each be REFUSED (combined)"
	nc=0
	for d in fixtures/violations/combined/*/; do
		[ -d "$d" ] || continue
		nc=$((nc + 1))
		assert_refused "$d" "$CONFTEST" test --combine "$d" --policy "$POLICY_COMBINED" --data "$DATA" --all-namespaces
	done
	# PER-CLASS vacuity guards, not one total. A single 'n > 0' would stay green
	# after deleting every combined fixture - which would silently drop the only
	# negative controls FIN-001 and SEC-003 have.
	[ "$np" -gt 0 ] || { echo "no per-file violation fixtures - that class of negative control is vacuous" >&2; exit 1; }
	[ "$nc" -gt 0 ] || { echo "no combined violation fixtures - that class of negative control is vacuous" >&2; exit 1; }
	echo "$np per-file + $nc combined = $((np + nc)) negative controls, all refused."
}

# Every rule ID a policy can emit must actually be emitted by some violation
# fixture. Without this, a new rule (or a new clause) can ship with no refusing
# fixture and CI stays green because OTHER fixtures are still refused - exactly
# the gap that let FIN-002 reach CI uncovered.
#
# SCOPE: this pass is ID-level. A rule with several deny bodies sharing one ID
# counts as covered once any of them fires, so it cannot see a dead clause
# hiding behind live siblings. That was a stated, unfixed limit until
# 2026-08-27; t_clause_coverage below now closes it and runs as the second half
# of this target. Both passes are kept, because they fail for different reasons
# and the ID-level message is the readable one.
t_coverage() {
	say "rule-ID coverage: every declared ID must be refused by some fixture"
	tmp=${TMPDIR:-/tmp}/nac-cov.$$
	mkdir -p "$tmp"
	grep -rhoE '"[A-Z]{3}-[0-9]{3}(-[A-Z]+)?:' "$POLICY" | tr -d '":' | sort -u > "$tmp/declared"
	{
		for f in fixtures/violations/perfile/*; do
			[ -f "$f" ] || continue
			"$CONFTEST" test "$f" --policy "$POLICY" --data "$DATA" --all-namespaces -o json 2>/dev/null || true
		done
		for d in fixtures/violations/combined/*/; do
			[ -d "$d" ] || continue
			"$CONFTEST" test --combine "$d" --policy "$POLICY_COMBINED" --data "$DATA" --all-namespaces -o json 2>/dev/null || true
		done
	} | grep -oE '[A-Z]{3}-[0-9]{3}(-[A-Z]+)?:' | tr -d ':' | sort -u > "$tmp/observed"
	comm -23 "$tmp/declared" "$tmp/observed" > "$tmp/missing"
	echo "declared IDs: $(tr '\n' ' ' < "$tmp/declared")"
	echo "refused IDs : $(tr '\n' ' ' < "$tmp/observed")"
	if [ -s "$tmp/missing" ]; then
		echo "FAIL: these rule IDs have no violation fixture that CI refuses:" >&2
		cat "$tmp/missing" >&2
		rm -rf "$tmp"
		exit 1
	fi
	rm -rf "$tmp"
	echo "every declared rule ID is exercised by a refusing fixture."

	t_clause_coverage
}

# CLAUSE-level coverage - the second half of the same question, and the one the
# ID-level pass above cannot answer.
#
# A rule ID is several deny bodies. The pass above counts an ID covered once ANY
# of them fires, so a body that fires for nothing hides behind its siblings.
# That is not hypothetical: on 2026-08-24 SEC-001's aws_security_group_rule +
# ::/0 body had no fixture in the CI loop and deleting it would not have turned
# the gate red. It was found by hand. The next one would not be.
#
# HOW, and why not by tagging messages. The obvious approach - stamp a clause
# id into every deny message and grep for it - would rewrite the text of all 18
# fixtures' expected output, a large share of the unit tests, and the README
# demo line, to make the gate legible to itself. So the property is asserted
# directly instead:
#
#   deleting a deny clause must reduce the deny count of at least one
#   fixture under fixtures/violations/
#
# A clause whose removal changes nothing is a clause no negative control
# exercises. No message, fixture or test changes to support this.
#
# WHAT COUNTS AS A CONTROL: only fixtures/violations/. A clause that is
# load-bearing solely for a finding in fixtures/historical/ reads UNCOVERED
# here, deliberately - a historical finding is evidence of what was shipped,
# not a control over what may ship. That sentence prints with any failure.
#
# TWO HONEST LIMITS. (1) Two clauses rendering identical text for the same
# fixture collapse under Rego's set semantics and would read as uncovered - an
# over-strict false red, the safe direction, and a real smell worth surfacing.
# (2) This proves each clause is load-bearing for SOME fixture, not that the
# fixture exercises it for the right reason.
t_clause_coverage() {
	say "clause coverage: every deny clause must be load-bearing for some refusing fixture"
	echo "A negative control means a fixture under fixtures/violations/. A clause that"
	echo "fires only on fixtures/historical/ reads UNCOVERED here by design: a historical"
	echo "finding is evidence of what was shipped, not a control over what may ship."

	rm -rf "$CLAUSE_TMP"
	mkdir -p "$CLAUSE_TMP"

	base=$CLAUSE_TMP/baseline.txt
	clause_fixture_counts "$POLICY" > "$base"
	if grep -q '^PARSE-ERROR' "$base"; then
		echo "FAIL: the unmutated policy tree could not be evaluated; every later" >&2
		echo "comparison would be against a baseline that is itself a tool error." >&2
		grep '^PARSE-ERROR' "$base" >&2
		rm -rf "$CLAUSE_TMP"
		exit 1
	fi

	nclause=0
	nuncovered=0
	uncov=$CLAUSE_TMP/uncovered.txt
	: > "$uncov"

	for f in "$POLICY"/*.rego "$POLICY_COMBINED"/*.rego; do
		[ -f "$f" ] || continue
		# COUNTED WITH awk, NOT `grep -c`. grep exits 1 when the count is zero,
		# so `n=$(grep -c ...)` on a file whose only clause was just deleted
		# kills the script under `set -e` - silently, with no message, after
		# printing 13 successful lines. `|| true` would paper over it and is
		# banned here; awk simply exits 0 and prints the number.
		before=$(awk '/^deny contains msg if/{n++} END{print n+0}' "$f")
		for ln in $(grep -nE '^deny contains msg if' "$f" | cut -d: -f1); do
			nclause=$((nclause + 1))

			# Fresh copy per clause: mutations must never compound.
			rm -rf "$CLAUSE_TMP/policy"
			cp -R "$POLICY" "$CLAUSE_TMP/policy"
			target=$CLAUSE_TMP/policy/${f#"$POLICY"/}

			# Excise from the deny head through the next closing brace at column
			# 0. Clause bodies are tab-indented throughout this tree, so the
			# first unindented '}' is always this clause's own close.
			awk -v s="$ln" 'NR<s{print;next} NR==s{skip=1;next} skip && $0=="}"{skip=0;next} skip{next} {print}' "$f" > "$target"

			# THE MUTATION MUST HAVE HAPPENED. A slice that removed nothing - or
			# removed two clauses - would produce a verdict the harness invented
			# rather than measured, and the "removed nothing" case reads as
			# UNCOVERED, which is a false accusation rather than a false pass.
			after=$(awk '/^deny contains msg if/{n++} END{print n+0}' "$target")
			if [ "$after" -ne $((before - 1)) ]; then
				echo "FAIL: harness error - excising $f:$ln removed $((before - after)) clause(s), expected exactly 1." >&2
				rm -rf "$CLAUSE_TMP"
				exit 1
			fi

			out=$CLAUSE_TMP/mutated.txt
			clause_fixture_counts "$CLAUSE_TMP/policy" > "$out"
			if grep -q '^PARSE-ERROR' "$out"; then
				echo "FAIL: deleting $f:$ln left a tree conftest could not evaluate." >&2
				echo "A tool error is not evidence that the clause was unnecessary." >&2
				grep '^PARSE-ERROR' "$out" >&2
				rm -rf "$CLAUSE_TMP"
				exit 1
			fi

			# Covered iff SOME fixture emits fewer denies without this clause.
			prover=$(awk 'NR==FNR{b[$1]=$2;next} ($1 in b) && ($2 < b[$1]) {print $1; exit}' "$base" "$out")
			if [ -n "$prover" ]; then
				echo "  covered   $f:$ln  <- $prover"
			else
				echo "  UNCOVERED $f:$ln"
				echo "$f:$ln" >> "$uncov"
				nuncovered=$((nuncovered + 1))
			fi
		done
	done

	# Vacuity guard, same reasoning as t_violations': a loop that iterated
	# nothing must not report success.
	[ "$nclause" -gt 0 ] || { echo "no deny clauses found - this check is vacuous" >&2; rm -rf "$CLAUSE_TMP"; exit 1; }

	if [ "$nuncovered" -gt 0 ]; then
		echo "FAIL: $nuncovered of $nclause deny clause(s) can be deleted without any" >&2
		echo "fixture under fixtures/violations/ noticing. Each needs a fixture the gate" >&2
		echo "must refuse, or the clause should go:" >&2
		cat "$uncov" >&2
		rm -rf "$CLAUSE_TMP"
		exit 1
	fi

	rm -rf "$CLAUSE_TMP"
	echo "all $nclause deny clauses are load-bearing for a refusing fixture. Nothing skipped."
}

# Two combined SETS, deliberately not one. A "set" is a unit that shares a
# configuration scope: the terraform root module for FIN-001 (provider
# default_tags applies module-wide), the kube manifest tree for SEC-003.
# Merging them would evaluate a provider block against Kubernetes docs.
t_combined() {
	for scope in kube terraform; do
		say "cross-file rules over historical $scope/ (combined mode)"
		c=$(deny_count "$CONFTEST" test --combine "$HIST/$scope" --policy "$POLICY_COMBINED" --data "$DATA" --all-namespaces)
		[ "$c" != "ERR" ] || { echo "TOOL ERROR evaluating $HIST/$scope" >&2; exit 1; }
		show_with_count "$c" "$CONFTEST" test --combine "$HIST/$scope" --policy "$POLICY_COMBINED" --data "$DATA" --all-namespaces
	done
}

# The self-audit. Non-zero is EXPECTED here - but it is asserted by exact
# count, never swallowed by '|| true'. A rule that silently stops firing
# breaks this target just as loudly as a new finding does.
t_historical() {
	say "self-audit: rules run against my own prior operated config"
	pf=$(deny_count "$CONFTEST" test "$HIST" --policy "$POLICY" --data "$DATA" --all-namespaces)
	cfk=$(deny_count "$CONFTEST" test --combine "$HIST/kube" --policy "$POLICY_COMBINED" --data "$DATA" --all-namespaces)
	cft=$(deny_count "$CONFTEST" test --combine "$HIST/terraform" --policy "$POLICY_COMBINED" --data "$DATA" --all-namespaces)
	for v in "$pf" "$cfk" "$cft"; do
		[ "$v" != "ERR" ] || { echo "TOOL ERROR: conftest could not evaluate the historical tree; a count of 0 would be a lie." >&2; exit 1; }
	done
	total=$((pf + cfk + cft))
	echo "per-file findings          : $pf"
	echo "combined findings (kube)   : $cfk"
	echo "combined findings (tfroot) : $cft"
	echo "total                      : $total (expected $HISTORICAL_EXPECTED)"
	if [ "$total" -ne "$HISTORICAL_EXPECTED" ]; then
		echo "FAIL: historical finding count moved. Either a rule regressed or STATUS.md is now stale." >&2
		exit 1
	fi
	# Display re-runs. Their non-zero exits are tolerated ONLY because the counts
	# above already proved the exits come from real deny messages - which is why
	# there is no '|| true' anywhere in this file.
	show_with_count "$pf" "$CONFTEST" test "$HIST" --policy "$POLICY" --data "$DATA" --all-namespaces
	show_with_count "$cfk" "$CONFTEST" test --combine "$HIST/kube" --policy "$POLICY_COMBINED" --data "$DATA" --all-namespaces
	show_with_count "$cft" "$CONFTEST" test --combine "$HIST/terraform" --policy "$POLICY_COMBINED" --data "$DATA" --all-namespaces
}

t_verify_provenance() {
	say "provenance: vendored bytes vs recorded blob SHAs"
	# NB: no 'cd' here on purpose. This function used to cd into $HIST and never
	# return, which left every later target running from fixtures/historical/ and
	# broke relative tool paths (../.tools/opa.exe). Paths are prefixed instead.
	fail=0
	while read -r sha path; do
		[ -n "$sha" ] || continue
		act=$(git hash-object "$HIST/$path")
		if [ "$act" != "$sha" ]; then
			echo "MISMATCH $path expected=$sha actual=$act" >&2
			fail=1
		fi
	done < "$HIST/BLOBSHAS.txt"
	[ "$fail" -eq 0 ] || { echo "FAIL: vendored fixtures have been modified." >&2; exit 1; }

	# THE LOOP ABOVE ONLY PROVES RECORDED FILES ARE UNMODIFIED. It is blind to
	# files that were ADDED, because it iterates the ledger, not the tree. On
	# 2026-08-26 an `infracost breakdown` run executed inside this directory
	# wrote a 22MB, 822-file .infracost/ module cache into the evidence tree.
	# Every one of the 22 blob SHAs still matched. The only thing that noticed
	# was the historical finding count, which moved 13 -> 100 - and it noticed
	# by luck, because the downloaded third-party modules happened to trip
	# OBS-001. An addition that tripped no rule would have gone unremarked and
	# been committed as evidence. So the tree must contain EXACTLY the recorded
	# set. BLOBSHAS.txt and PROVENANCE.md are the ledger itself, not evidence,
	# and are the only permitted extras.
	prov_tmp=${TMPDIR:-/tmp}/nac-prov.$$
	mkdir -p "$prov_tmp"
	awk '{print $2}' "$HIST/BLOBSHAS.txt" | sort > "$prov_tmp/recorded"
	(cd "$HIST" && find . -type f ! -name BLOBSHAS.txt ! -name PROVENANCE.md) |
		cut -c3- | sort > "$prov_tmp/actual"
	comm -13 "$prov_tmp/recorded" "$prov_tmp/actual" > "$prov_tmp/extra"
	comm -23 "$prov_tmp/recorded" "$prov_tmp/actual" > "$prov_tmp/absent"
	if [ -s "$prov_tmp/extra" ] || [ -s "$prov_tmp/absent" ]; then
		[ -s "$prov_tmp/extra" ] && {
			echo "FAIL: unrecorded files present in the evidence tree ($(wc -l < "$prov_tmp/extra") of them):" >&2
			head -10 "$prov_tmp/extra" >&2
		}
		[ -s "$prov_tmp/absent" ] && {
			echo "FAIL: recorded files missing from the evidence tree:" >&2
			cat "$prov_tmp/absent" >&2
		}
		rm -rf "$prov_tmp"
		exit 1
	fi
	rm -rf "$prov_tmp"

	echo "$(wc -l < "$HIST/BLOBSHAS.txt") files verified against PROVENANCE.md, and the tree contains exactly that set."
}

t_parse() {
	say "parse shapes (regenerates the evidence behind docs/parse-shape.md)"
	for f in "$HIST/terraform/vpc.tf" "$HIST/terraform/variables.tf" \
		"$HIST/terraform/envs/dev.tfvars" "$HIST/kube/base/egress-common.yaml"; do
		echo "---------- $f"
		"$CONFTEST" parse "$f"
	done
}

t_demo() {
	say "DEMO: the gate refusing a violation"
	set +e
	"$CONFTEST" test fixtures/violations/perfile/netpol-wide-ipblock.yaml --policy "$POLICY" --data "$DATA" --all-namespaces
	rc=$?
	set -e
	echo "conftest exit code: $rc (non-zero = refused)"
	[ "$rc" -ne 0 ] || { echo "DEMO BROKEN: the violation was accepted." >&2; exit 1; }
}

t_gate() {
	t_verify_provenance
	t_unit
	t_conforming
	t_violations
	t_coverage
	t_historical
	say "GATE GREEN"
}

case "${1:-gate}" in
	tools) t_tools ;;
	unit) t_unit ;;
	conforming) t_conforming ;;
	violations) t_violations ;;
	coverage) t_coverage ;;
	combined) t_combined ;;
	historical) t_historical ;;
	verify-provenance) t_verify_provenance ;;
	parse) t_parse ;;
	demo) t_demo ;;
	gate) t_gate ;;
	*) echo "unknown target: $1" >&2; exit 2 ;;
esac
