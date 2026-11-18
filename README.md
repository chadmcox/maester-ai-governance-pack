# Copilot AI Governance

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
| MP.AIGOV.1001 | Agent catalog adoption is below a configurable threshold over the D90 report period | Preview | Adoption branch not yet validated, Graph only |
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
| MP.AIGOV.1015 | Spending policy cap should not be overridden by a more permissive overlapping policy | Preview | Validated, Graph only |
| MP.AIGOV.1016 | MCP server should not use weak or no authentication | Preview | Validated, Graph only |
| MP.AIGOV.1017 | Conditional Access should cover agent identities | Preview | Validated, Graph only |
| MP.AIGOV.1018 | Agent identity currently at risk should be remediated or dismissed | Preview | Validated, Graph only |
| MP.AIGOV.1019 | Agent identity should not have user-consented delegated permissions | Preview | Validated, Graph only |
| MP.AIGOV.1020 | Custom agent or tool that nobody uses should be blocked or removed | Preview | Validated, Graph only |
| MP.AIGOV.1021 | Group an agent or tool is assigned to should exist, have two owners and a description | Preview | Validated, Graph only |
| MP.AIGOV.1022 | Agent identity should not hold broad Microsoft Graph write permissions | Preview | Validated, Graph only |
| MP.AIGOV.1023 | Agent identity and blueprint should have a clear name and description | Preview | Validated, Graph only |
| MP.AIGOV.1024 | Classic Copilot Studio service principal should have an owner and be in use | Preview | Validated (empty-inventory case), Graph only |
| MP.AIGOV.1025 | Spending policy should be scoped to a group and fully configured | Preview | Validated, Graph only |
| MP.AIGOV.1026 | Enabled spending policy should alert at least two active recipients | Preview | Validated, Graph only |
| MP.AIGOV.1027 | Group behind a spending policy should be a populated security group without nesting | Preview | Validated, Graph only |
| MP.AIGOV.1032 | Spending policy groups should contain only enabled, active, licensed members | Preview | Validated (5,000-member cap), Graph only |
| MP.AIGOV.1033 | Copilot connectors users can search should only take content from apps you govern | Preview | Validated, Graph only |
| MP.AIGOV.1034 | AI administration roles should be eligible through PIM and held by a small number of internal users | Preview | Validated, Graph only |
| MP.AIGOV.1035 | Agent identity blueprints should not authenticate with client secrets | Preview | Validated, Graph only |
| MP.AIGOV.1036 | Enabled agent identities should have at least one active sponsor | Preview | Validated, Graph only |
| MP.AIGOV.1037 | Agents discovered by Microsoft Defender should have a Microsoft Entra identity | Preview | Validated, Graph (advanced hunting) |
| MP.AIGOV.1038 | MCP tools should match the definitions you approved | Preview | Not yet validated, Graph only |
| MP.AIGOV.1039 | MCP tool descriptions should describe the tool, not instruct the model | Preview | Not yet validated, Graph only |
| MP.AIGOV.1040 | Sensitivity labels should include a sites and groups label and use unique names | Preview | Validated, Graph only |
| MP.AIGOV.1041 | Agent identity blueprints from other organizations should come from a verified publisher | Preview | Not yet validated, Graph only |
| MP.AIGOV.1042 | Web search in Copilot should be off, or limited to Web mode | Preview | Validated (unconfigured-policy case), Graph (delegated only) |
| MP.AIGOV.1043 | Copilot DLP policies should block sensitive prompts, labeled content, and web search for sensitive prompts | Preview | Not yet validated, Security & Compliance |
| MP.AIGOV.1044 | Copilot interaction audit records should be retained for at least your required period | Preview | Validated (missing-policy case), Security & Compliance |
| MP.AIGOV.1045 | Azure OpenAI and AI Services accounts should require Entra auth, restrict network access and be covered by Defender for AI | Preview | Not yet validated, Azure |

**Scope of the connector checks.** MP.AIGOV.1007, 1008, 1010, 1011, 1016, 1038 and 1039 only report on catalog
packages users can reach: a package that is blocked (`isBlocked`) or allowed for no one
(`availableTo = allowedForNone`) is skipped, and the result says how many were skipped. MP.AIGOV.1033
does the same for synced Copilot connectors, covering only connections in the `ready` or
`limitExceeded` state.

**Connections.** Tests 1001–1042 need only Microsoft Graph. Three tests reach other services Maester already
connects to; they skip when that service isn't connected:

```powershell
Connect-Maester -Service Graph, ExchangeOnline, SecurityCompliance, Azure
```

| Test | Service | Why |
| --- | --- | --- |
| MP.AIGOV.1043 | Exchange Online + Security & Compliance | DLP rule actions for the Copilot location aren't in Graph |
| MP.AIGOV.1044 | Security & Compliance | Audit log retention policies aren't in Graph |
| MP.AIGOV.1045 | Azure | Azure OpenAI and AI Services accounts and Defender plans |

MP.AIGOV.1042 reads an API that supports delegated permissions only, so it skips in an app-only run.
MP.AIGOV.1037 needs Microsoft Defender XDR with Microsoft Agent 365 for the `AgentsInfo` table.

**Settings.** Four tests read `GlobalSettings` from `maester-config.json`:

| Setting | Default | Used by |
| --- | --- | --- |
| `AIGOV.MaxAiAdminRoleHolders` | `3` | MP.AIGOV.1034 |
| `AIGOV.McpToolBaseline` | empty (test skips and prints current fingerprints) | MP.AIGOV.1038 |
| `AIGOV.McpSteeringPatterns` | 8 built-in patterns | MP.AIGOV.1039 |
| `AIGOV.MinimumAiAuditRetention` | `TwelveMonths` | MP.AIGOV.1044 |

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

### Framework controls with no automated check yet

These come from CISA's draft SCuBA agent baseline (`MS.SI.*`), CISA/NSA *Careful Adoption of Agentic AI Services*,
and NIST AI RMF. They are either process controls, or settings with no API that Maester can read today
(see [`docs/coverage-matrix.md`](docs/coverage-matrix.md), section "Framework gap review (2026-11-18)").

| Check | Source | Why it's manual |
| --- | --- | --- |
| Public publishing of agents is turned off, and agents on non-Microsoft channels are inventoried and approved | MS.SI.4.2, 13.3 | Copilot Studio settings live in Dataverse; Maester's Dataverse reader isn't exported to packs |
| Agent knowledge sources carry the required protection | MS.SI.13.2 | Same Dataverse limitation |
| Power Platform DLP covers the default environment and every agent environment, restricts connector combinations, and tenant isolation is on | MS.SI.13.5; SCuBA MS.POWERPLATFORM.1–3 | Maester has no Power Platform admin connection (ScubaGear checks the SCuBA Power Platform baseline) |
| Copilot Studio external threat detection is configured with error behavior "Block the query" | MS.SI.13.6 | Power Platform admin center setting with no documented read API |
| Pay-as-you-go billing isn't linked to agent environments | MS.SI.13.1 | CISA hasn't published the instructions; confirm what it means |
| Restricted Content Discovery is applied to unreviewed or high-risk SharePoint sites (Restricted SharePoint Search is retiring: no new enablement after July 31, 2026) | MS.SI.9.1, 9.3, 10.7 | Needs a per-site decision; read with `Get-SPOSite` / `Start-SPORestrictedContentDiscoverabilityReport` |
| Endpoint DLP covers third-party generative AI sites; unsanctioned AI apps are blocked in Defender for Cloud Apps | MS.SI.10.4 | Rule shape not verified |
| Retention covers Enterprise AI apps and Other AI apps, not only Microsoft Copilot experiences | MS.SI.11.5 | `MT.1176` covers Copilot; app identifiers for the other locations aren't documented |
| A Communication Compliance policy covers AI interactions, with reviewers and a triage schedule | MS.SI.12.1, 12.2 | Location values not verified |
| Copilot Studio agent traffic goes through Global Secure Access, with web content filtering and prompt injection protection on the baseline profile | CISA agentic (input filtering, segmentation) | Prompt policy type not documented in Graph |
| DSPM for AI is on, its recommendations are completed or dismissed on record, and reports are reviewed on a schedule; AI interactions are findable in eDiscovery | MS.SI.11.1–11.3, 11.6 | No documented API |
| A data risk assessment was completed before turning on Copilot or agents | MS.SI.9.2; AI RMF MAP 1.1 | Process |
| Agents are red-teamed in a sandbox before production; an incident response plan covers a compromised agent; a named owner decides which actions need human approval | CISA agentic; AI RMF MEASURE 2.7, MANAGE 2.4, GOVERN 2.1 | Process |
