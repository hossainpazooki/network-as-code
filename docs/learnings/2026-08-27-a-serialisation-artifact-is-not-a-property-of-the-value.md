# A serialisation artifact is not a property of the value

ts: 2026-08-27T00:02:00Z
commit: (none - uncommitted at capture time; repo HEAD a626b58 predates it)
session: https://claude.ai/code/session_014VvchHADG6EdNs3w8JrKY6
status: verified
fact: What a tool PRINTS and what a policy engine SEES are different artifacts, and a contract document written by reading printed output will record encoding quirks as if they were properties of the data. JSON encoders may emit non-ASCII and certain ASCII characters as escape sequences; those sequences exist only in the transport text. Any consumer that parses the JSON - which is every consumer - gets the decoded character. A rule author told to "compare with the escaped form" writes a comparison against a string the engine will never hold.
basis: `gates/docs/parse-shape.md` carried, from 2026-08-24, "`>` in version constraints is HTML-escaped: `"~> 5.0"`. Compare with the escaped form or use `contains()` on a substring that avoids it." Two errors in two sentences. First, it is not HTML escaping - HTML would be `&gt;`; conftest's JSON encoder emits the six characters `u003e` preceded by a backslash. Second, the escaping is transport-only: `conftest parse fixtures/historical/terraform/vpc.tf` prints the escape, and the decoded value is the ordinary three-character string `~> 5.0`. Verified 2026-08-27 by evaluating three deny clauses against that file - `mod.version == "~> 5.0"`, the same literal written with the escape (identical to the Rego parser, which decodes it too), and `contains(mod.version, ">")`. All three matched; conftest reported 3 tests, 0 passed, 3 failures. The advice as written was never followed, so no rule shipped dead - but an author who took "HTML-escaped" literally and wrote `&gt;` would have shipped a clause that could never fire, in the contract document whose stated purpose is to prevent exactly that.
re-verify: cd ~/dev/network-as-code/gates && ../.tools/conftest.exe parse fixtures/historical/terraform/vpc.tf | python -c "import json,sys; s=sys.stdin.read(); print('escape present in SERIALISED text:', 'u003e' in s); print('decoded VALUE is:', repr(json.loads(s)['module']['vpc'][0]['version']))"

The generalisation: a document that records "the observed parse shape" must
distinguish the bytes a tool printed from the values a consumer will bind. Where
the two differ, say which one the rule sees - and prove it by running a
comparison, not by reading the output. A quirk filed under "cosmetic" is exactly
where this hides, because cosmetic implies nothing depends on it. Related:
[[2026-08-25-conftest-combine-changes-input-shape]], the other case in this
ledger where the shape a rule is written against was not the shape it received.
