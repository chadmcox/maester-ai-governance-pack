# Pilot (Gap, Graph-only) + remaining open questions

Revision 2 — approved for Phase 2 with the fixes below applied. Renumbered to
`MP.AIGOV.1001`–`1007` (contiguous; nothing has shipped, so no gap-numbering is
preserved from the prior draft).

## Recommended pilot: 7 Gap findings, Graph-only (no Dataverse/Defender/billing)

Five of these (`.1001`, `.1002`, `.1003`, `.1006`, `.1007`) read the Package
Management API (`GET /copilot/admin/catalog/packages`), which is Graph v1.0 and
needs no Dataverse or Power Platform connection — but it is gated behind a
**Microsoft Agent 365 license**. A direct call against the test tenant returned
`403 Forbidden`. **A 403 alone does not prove a license gap** — it is equally
consistent with `CopilotPackages.Read.All` never having been consented. All five
must Skip cleanly (not Fail) on a 403, using `SkippedBecause NotAuthorized` with a
message that names **both** possible causes explicitly, e.g.:

> "Couldn't read the Copilot package catalog (403). This requires a Microsoft
> Agent 365 license and the CopilotPackages.Read.All permission — confirm both
> before re-running this check."

| Draft test ID | Title | Severity | Surface | Data source | Skip condition |
|---|---|---|---|---|---|
| `MP.AIGOV.1001` | Agent catalog adoption below a configurable threshold (default 5%) over the fixed D90 report period | Low | Agents | Graph beta `copilot/reports/getMicrosoft365CopilotUsageUserDetail(period='D90')`, `Reports.Read.All`. Report period is **fixed at D90** (not configurable); only the **5% threshold** is configurable. Carried over from `chadmcox/Copilot`: (1) run only when the package catalog reports ≥1 agent (so this also depends on the Package API / Agent 365 license, not just the usage report), (2) skip when the report has fewer than 20 users, (3) the agent-activity column is undocumented — find it by name-matching columns containing both `Agent` and `Activity`, don't hard-code a column name | No Copilot usage license/report access; fewer than 1 agent in the catalog (also requires Agent 365/Package API); fewer than 20 reported users; no column matches the `*Agent*Activity*` name pattern |
| `MP.AIGOV.1002` | Blocked package has an open pending install/consent request | Low | Agents | Graph v1.0 `copilot/admin/catalog/packages` (`isBlocked` + `requestStatus`/`requestType` filters), `CopilotPackages.Read.All` | `NotAuthorized` (403 — Agent 365 license not present, or `CopilotPackages.Read.All` not consented; message names both) |
| `MP.AIGOV.1003` | Agent assigned directly to users instead of via a group | Low | Agents | **Per-package only** — `GET /copilot/admin/catalog/packages/{id}` returns `allowedUsersAndGroups` and `acquireUsersAndGroups`; filter each to entries where `resourceType eq 'user'`. The list endpoint (`GET /copilot/admin/catalog/packages`) does **not** return these audience collections, so this must be a per-package detail call, not derivable from the list response | `NotAuthorized` (403 — license or consent, message names both) |
| `MP.AIGOV.1004` | Agent identity, blueprint, or blueprint principal has exactly one sponsor and zero owners (single point of failure) | Low | Agent identities / Blueprints / Blueprint Principals | **Extended to agent identities**, not just Blueprints/Blueprint Principals: agent identities also expose a `sponsors` relationship via `$expand=sponsors` (confirmed working — `chadmcox/Copilot` already uses this call shape). Rule applies uniformly across all three object types: sponsor count == 1 **AND** owner count == 0 | None identified (same base permission as MT.1205) |
| `MP.AIGOV.1005` | Classic Copilot Studio service principal has no corresponding Agent ID registration | Info | Agents without Agent ID | Graph v1.0 `servicePrincipals` filtered by Copilot Studio tags — `AgentCreatedBy:CopilotStudio`, `AgenticApp`, `AIAgentBuilder`, `AgenticInstance`, `power-virtual-agents-*` — cross-referenced against `microsoft.graph.agentIdentity` objects; tag-based, not a bot-list cross-reference | None identified |
| `MP.AIGOV.1006` | Agent display name or description is empty or a placeholder value | Info | Agents | Graph v1.0 `copilot/admin/catalog/packages` (`displayName`/`description`), `CopilotPackages.Read.All` | `NotAuthorized` (403 — license or consent, message names both) |
| `MP.AIGOV.1007` | Custom or external (non-Microsoft-published) package is available or deployed tenant-wide (`availableTo=allowedForAll` / `deployedTo=acquiredForAll`) | **High** | Agents | Graph v1.0 `copilot/admin/catalog/packages` (`availableTo`: `packageAllowStatus`, `deployedTo`: `packageAcquireStatus`), `CopilotPackages.Read.All`. "Microsoft-published" must be an explicit, written allowlist of `publisher` values, not an assumption — treat exactly these as Microsoft-published: `Microsoft Corporation`, `Microsoft`, `Microsoft 365`, `Microsoft Copilot Studio`. Any other `publisher` value (including blank/null) counts as custom/external for this check. Revisit this list once a licensed tenant confirms the real observed value set. | `NotAuthorized` (403 — license or consent, message names both) |

Dropped from this pilot (not added back): billing/spending-policy findings remain
out of the pilot per your decision — they stay in the matrix as Gaps, not here.

All items should ship as `Lifecycle = 'Preview'` (matching Maester's own convention
for every MT.12xx agent-identity test) and use `SkippedBecause Custom` with a
pack-local `Get-AIGovSkippedReason` helper, mirroring `Get-MtAIAgentSkippedReason`,
except where `NotAuthorized` is the more precise built-in skip reason (the five
package-API-dependent items above).

## Phase 2 build order

**Build and validate now** (Graph only, no Agent 365 dependency):
- `MP.AIGOV.1004` (sponsors/owners — agent identities, blueprints, blueprint principals)
- `MP.AIGOV.1005` (classic SP without Agent ID, via service principal tags)

**Build, but mark NOT VALIDATED** until an Agent-365-licensed test tenant is
available to confirm the live schema and skip behavior:
- `MP.AIGOV.1001`, `MP.AIGOV.1002`, `MP.AIGOV.1003`, `MP.AIGOV.1006`, `MP.AIGOV.1007`

Skills and MCP stay fully out of scope until a licensed tenant confirms the
`elementType`/package-API schema (see coverage-matrix.md's "Skills and MCP —
surface redefinition" section).

The MT.1205/MT.1208 granular split stays in the matrix exactly as currently
written (four Covered rows for MT.1208, zero-sponsor-only scope for MT.1205).

**Optional, not required for Phase 2 to start:** draft an upstream issue against
`maester365/maester` for the declared-vs-shipped severity mismatch found in both
`Test.MT.1118.ps1` (declared `Medium`, emits `Severity 'High'`) and
`Test.MT.1208.ps1`'s first condition (same pattern).

## Decisions already made (carried over, not re-asked)

- Pack code: `AIGOV` — checked `packs.maester.cloud`'s public index; unclaimed.
- Repo created: `chadmcox/maester-ai-governance-pack`, public, MIT license.
- Billing excluded from the pilot (still in the matrix as Gaps).
- Revision 2 approved for Phase 2, with the fixes in this document applied.
