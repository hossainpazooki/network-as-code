# A dynamic data[var] reference inside package main is a compile error

ts: 2026-08-25T02:48:53Z
commit: (none - repository had zero commits at capture time; working tree of 2026-08-25)
session: https://claude.ai/code/session_01RKDcJkwv49bhi7kbKLscpb
status: verified
fact: In a policy whose package is `main`, a DYNAMIC data reference (`data[env]`, where env is a variable) fails to compile with `rego_recursion_error: rule data.main.deny is recursive`, because the dynamic key can range over `data.main` itself. A STATIC reference (`data.dev`) compiles and resolves normally. Any per-environment lookup out of an external data file must therefore be written as explicit static paths, never as `data[env]`.
basis: a scratch policy containing `env := "dev"` then `d := data[env]`, run as `conftest test fixtures/historical/terraform/vpc.tf --policy <tmpdir> --data policy --all-namespaces`, printed `Error: running test: load: loading policies: get compiler: 1 error occurred: ...p.rego:3: rego_recursion_error: rule data.main.deny is recursive: data.main.deny -> data.main.deny`. The same policy using `d := data.dev` compiles and prints `data.dev={"monthly_usd_max": 250.0}`.
re-verify: d=$(mktemp -d); python -c "import io,sys; io.open(sys.argv[1]+'/p.rego','w',newline=chr(10)).write('package main'+chr(10)*2+'deny contains msg if {'+chr(10)+'e := \"dev\"'+chr(10)+'msg := sprintf(\"%v\", [data[e]])'+chr(10)+'}'+chr(10))" "$d"; (cd gates && ../.tools/conftest.exe test fixtures/historical/terraform/vpc.tf --policy "$d" --all-namespaces 2>&1) | grep -q rego_recursion_error && echo CONFIRMED

Cost of not knowing this: the shipped `budget_max_for(env) := data[env].monthly_usd_max`
carried a code comment claiming an external budget file would become authoritative
"with zero rule changes" once a `--data` flag was added. That path could never have
resolved - the rule would not even have compiled. Related:
[[2026-08-25-opa-test-and-conftest-load-data-differently]].
