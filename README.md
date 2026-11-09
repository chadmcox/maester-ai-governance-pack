# AI Governance

A [Maester Pack](https://maester.dev/docs/packs). Install it with:

```powershell
Install-MtPack chadmcox/maester-ai-governance-pack/pack
```

The installable pack lives in [`pack/`](pack/) (`maester-pack.json`, `tests/`, `helpers/`), not the
repo root. [`unit-tests/`](unit-tests/) holds this repo's own Pester unit tests and is not part of
the installed pack -- see the comment in
[`.github/workflows/test-pack.yml`](.github/workflows/test-pack.yml) for why.

## Tests

| ID | Title | Lifecycle | Status |
| --- | --- | --- | --- |
| MP.AIGOV.1001 | Agent catalog adoption is below a configurable threshold over the D90 report period | Preview | Validated, Graph only |
| MP.AIGOV.1002 | Blocked package has an open pending install or consent request | Preview | Validated, Graph only |
| MP.AIGOV.1003 | Agent is assigned directly to users instead of via a group | Preview | Validated, Graph only |
| MP.AIGOV.1004 | Agent identity, blueprint, or blueprint principal has exactly one sponsor and zero owners | Preview | Validated, Graph only |
| MP.AIGOV.1005 | Classic Copilot Studio service principal has no corresponding Agent ID registration | Preview | Validated, Graph only |
| MP.AIGOV.1006 | Agent display name or description is empty or a placeholder value | Preview | Validated, Graph only |
| MP.AIGOV.1007 | Custom or external package is available or deployed tenant-wide | Preview | Validated, Graph only |
| MP.AIGOV.1008 | MCP server endpoint should not be reachable over plain HTTP | Preview | Validated, Graph only |
| MP.AIGOV.1009 | Agent Identity Blueprint credential should not be nearing expiration | Preview | Validated, Graph only |
| MP.AIGOV.1010 | MCP server should be hosted on an allowlisted domain | Preview | Validated, Graph only |
| MP.AIGOV.1011 | MCP tool with a destructive or open-world effect should not be in a tenant-wide package | Preview | Validated, Graph only |
| MP.AIGOV.1012 | Agent skill should have a clear description, and should not be exposed to Copilot tenant-wide without review | Preview | Validated, Graph only |
| MP.AIGOV.1013 | Enabled spending policy should have a credit ceiling | Preview | Validated, Graph only |
| MP.AIGOV.1014 | Group backing a spending policy should have owners and a description | Preview | Validated, Graph only |
| MP.AIGOV.1015 | Spending policy cap should not be overridden by a more permissive overlapping policy | Preview | Revised, re-validation pending, Graph only |
| MP.AIGOV.1016 | MCP server should not use weak or no authentication | Preview | Validated, Graph only |
| MP.AIGOV.1017 | Conditional Access should cover agent identities | Preview | Validated, Graph only |
| MP.AIGOV.1018 | Agent identity currently at risk should be remediated or dismissed | Preview | Validated, Graph only |
| MP.AIGOV.1019 | Agent identity should not have user-consented delegated permissions | Preview | Validated, Graph only |
| MP.AIGOV.1020 | Custom agent or tool that nobody uses should be blocked or removed | Preview | Not yet validated, Graph only |
| MP.AIGOV.1021 | Group an agent or tool is assigned to should exist, have two owners and a description | Preview | Not yet validated, Graph only |
| MP.AIGOV.1022 | Agent identity should not hold broad Microsoft Graph write permissions | Preview | Not yet validated, Graph only |
| MP.AIGOV.1023 | Agent identity and blueprint should have a clear name and description | Preview | Not yet validated, Graph only |
| MP.AIGOV.1024 | Classic Copilot Studio service principal should have an owner and be in use | Preview | Not yet validated, Graph only |
| MP.AIGOV.1025 | Spending policy should be scoped to a group and fully configured | Preview | Not yet validated, Graph only |
| MP.AIGOV.1026 | Enabled spending policy should alert at least two active recipients | Preview | Not yet validated, Graph only |
| MP.AIGOV.1027 | Group behind a spending policy should be a populated security group without nesting | Preview | Not yet validated, Graph only |
| MP.AIGOV.1032 | Spending policy groups should contain only enabled, active, licensed members | Preview | Not yet validated, Graph only |
| MP.AIGOV.1033 | Copilot connectors users can search should only take content from apps you govern | Preview | Not yet validated, Graph only |

**Scope of the connector checks.** MP.AIGOV.1007, 1008, 1010, 1011 and 1016 only report on catalog
packages users can reach: a package that is blocked (`isBlocked`) or allowed for no one
(`availableTo = allowedForNone`) is skipped, and the result says how many were skipped. MP.AIGOV.1033
does the same for synced Copilot connectors, covering only connections in the `ready` or
`limitExceeded` state.

See [`docs/pilot-and-open-questions.md`](docs/pilot-and-open-questions.md) for the full data-source
and skip-condition rationale behind each test, and [`docs/coverage-matrix.md`](docs/coverage-matrix.md)
for how each one maps to existing Maester tests and framework controls.

## Manual checks

Conditions that are real governance risks but can't be automated today because the Microsoft 365
admin center exposes them with no corresponding Graph API (confirmed 2026-11-06; see `docs/coverage-matrix.md`
G29). Resource-based spending policies ("Resources" scope → Specific resource/Resource collection,
in the Cost management dashboard) are a case where the Graph beta `spendingPolicy` type documents
only `allUsersSpendingPolicy` and `selectedGroupsSpendingPolicy` — review these by hand in the admin
center until Microsoft exposes a resource-scoped type:

| Check | Why it matters |
| --- | --- |
| A resource policy's scope is "All environments" | Starting with specific environments and expanding deliberately is the documented guidance; an all-environments resource policy removes that control. |
| A resource policy has no per-agent limit set | An unlimited per-agent limit defeats the purpose of a resource-scoped cap. |
| An agent is covered by more than one enabled resource policy | Overlapping resource policies don't combine — the highest per-agent/per-user limit wins, which can silently grant a higher effective limit than intended. |
| An identity policy has "Auto-apply new services" turned on without review | Enabled by default tenant-wide (Message Center MC1470425, Sept 2026); newly released UBB services and agents automatically inherit policy coverage unless an admin reviews and disables it per policy. |
| A synced Copilot connector is rolled out to everyone, or set so every user sees all content | Graph doesn't expose a connection's staged-rollout audience or its item access rules. Review under Copilot > Connectors > Your connections. |
| AI Builder credits | Not covered by resource-based spending policies at all — see [Usage-based billing and cost management for Copilot Credits](https://learn.microsoft.com/copilot/implement/usage-based-billing-manage-copilot-studio-costs). |

