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
# SCOPE, stated because it is a real limit: this is ID-level, not clause-level.
# A rule with several deny bodies sharing one ID counts as covered once any of
# them fires. Clause-level coverage is NOT enforced - see STATUS.md.
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
	echo "$(wc -l < "$HIST/BLOBSHAS.txt") files verified against PROVENANCE.md."
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
