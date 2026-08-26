# Terraform default_tags is provider-wide, so a per-file tag rule reports untrue findings

ts: 2026-08-25T02:48:23Z
commit: (none - repository had zero commits at capture time; working tree of 2026-08-25)
session: https://claude.ai/code/session_01RKDcJkwv49bhi7kbKLscpb
status: refuted-assumption
fact: The assumption that a per-file policy could credit a resource's tags from a provider `default_tags` block is false in practice. `default_tags` is a property of the provider CONFIGURATION and applies to every resource in the root module regardless of which `.tf` file declares it; which file a resource occupies is a source-layout choice with no meaning to Terraform. A per-file rule sees the resource file WITHOUT the provider block and reports tags missing that are in fact applied at provision time. Any rule reading a provider-wide fact must run in combined mode over the whole root module.
basis: `conftest parse fixtures/historical/terraform/rds.tf` yielded top-level keys `['module', 'resource']` with `provider` present: False. `conftest parse fixtures/historical/terraform/versions.tf` yielded `default_tags` keys `['Environment', 'ManagedBy', 'Project']` with `resource` present: False. So the file declaring the tags has no resources, and every file with resources is blind to the tags.
re-verify: cd gates && ../.tools/conftest.exe parse fixtures/historical/terraform/rds.tf | python -c "import json,sys;d=json.load(sys.stdin);print('provider visible in rds.tf parse:', 'provider' in d)"

Consequence: FIN-001 emitted "missing required allocation tag(s) Environment, App"
for 8 historical resources when Environment was genuinely applied. The finding
COUNT was correct (8, because App really is absent) and the stated REASON was
wrong - and a gate that reports untrue findings is precisely what trains people
to ignore it. A hardcoded "pinned default_tags keys" constant was considered and
rejected: it would credit Environment even in a repo that never declares it, and
would make the credit untestable. FIN-001 moved to `gates/policy/combined/`,
which required [[2026-08-25-conftest-combine-changes-input-shape]].
