# Pilot (Gap, Graph-only) + remaining open questions

Revision 2 — approved for Phase 2 with the fixes below applied. Renumbered to
`MP.AIGOV.1001`–`1007` (contiguous; nothing has shipped, so no gap-numbering is
preserved from the prior draft).

## Recommended pilot: 7 Gap findings, Graph-only (no Dataverse/Defender/billing)

Five of these (`.1001`, `.1002`, `.1003`, `.1006`, `.1007`) read the Package
Management API (`GET /copilot/admin/catalog/packages`), which is Graph v1.0 and
needs no Dataverse or Power Platform connection. **Corrected 2026-11-05 with a
live validation run**: reading this endpoint may require a Microsoft Agent 365
license depending on tenant, but against the (F7-licensed) test tenant the
earlier `403 Forbidden` turned out to be a consent gap, not a license gate —
once `CopilotPackages.Read.All` was properly consented, all five calls
succeeded with no separate license observed. **A 403 alone still does not
prove a license gap** — it is equally consistent with
`CopilotPackages.Read.All` never having been consented. All five
must Skip cleanly (not Fail) on a 403, using `SkippedBecause NotAuthorized` with a
message that names **both** possible causes explicitly, e.g.:

> "Couldn't read the Copilot package catalog (403). This may require a Microsoft
> Agent 365 license depending on tenant, and the CopilotPackages.Read.All
> permission — confirm both before re-running this check."

| Draft test ID | Title | Severity | Surface | Data source | Skip condition |
|---|---|---|---|---|---|
| `MP.AIGOV.1001` | Agent catalog adoption below a configurable threshold (default 5%) over the fixed D90 report period | Low | Agents | Graph beta `copilot/reports/getMicrosoft365CopilotUsageUserDetail(period='D90')`, `Reports.Read.All`. Report period is **fixed at D90** (not configurable); only the **5% threshold** is configurable. Carried over from `chadmcox/Copilot`: (1) run only when the package catalog reports ≥1 agent (so this also depends on the Package API, which may require an Agent 365 license depending on tenant), (2) skip when the report has fewer than 20 users, (3) the agent-activity column is undocumented — find it by name-matching columns containing both `Agent` and `Activity`, don't hard-code a column name | No Copilot usage license/report access; fewer than 1 agent in the catalog (also depends on the Package API); fewer than 20 reported users; no column matches the `*Agent*Activity*` name pattern |
| `MP.AIGOV.1002` | Blocked package has an open pending install/consent request | Low | Agents | Graph v1.0 `copilot/admin/catalog/packages` (`isBlocked` + `requestStatus`/`requestType` filters), `CopilotPackages.Read.All` | `NotAuthorized` (403 — may be no Agent 365 license depending on tenant, or `CopilotPackages.Read.All` not consented; message names both) |
| `MP.AIGOV.1003` | Agent assigned directly to users instead of via a group | Low | Agents | **Per-package only** — `GET /copilot/admin/catalog/packages/{id}` returns `allowedUsersAndGroups` and `acquireUsersAndGroups`; filter each to entries where `resourceType eq 'user'`. The list endpoint (`GET /copilot/admin/catalog/packages`) does **not** return these audience collections, so this must be a per-package detail call, not derivable from the list response | `NotAuthorized` (403 — license or consent, message names both) |
| `MP.AIGOV.1004` | Agent identity, blueprint, or blueprint principal has exactly one sponsor and zero owners (single point of failure) | Low | Agent identities / Blueprints / Blueprint Principals | **Extended to agent identities**, not just Blueprints/Blueprint Principals: agent identities also expose a `sponsors` relationship via `$expand=sponsors` (confirmed working — `chadmcox/Copilot` already uses this call shape). Rule applies uniformly across all three object types: sponsor count == 1 **AND** owner count == 0 | None identified (same base permission as MT.1205) |
| `MP.AIGOV.1005` | Classic Copilot Studio service principal has no corresponding Agent ID registration | Info | Agents without Agent ID | Graph v1.0 `servicePrincipals` filtered by Copilot Studio tags — `AgentCreatedBy:CopilotStudio`, `AgenticApp`, `AIAgentBuilder`, `AgenticInstance`, `power-virtual-agents-*` — cross-referenced against `microsoft.graph.agentIdentity` objects; tag-based, not a bot-list cross-reference | None identified |
| `MP.AIGOV.1006` | Agent display name or description is empty or a placeholder value | Info | Agents | Graph v1.0 `copilot/admin/catalog/packages` (`displayName`/`description`), `CopilotPackages.Read.All` | `NotAuthorized` (403 — license or consent, message names both) |
| `MP.AIGOV.1007` | Custom or external (non-Microsoft-published) package is available or deployed tenant-wide (`availableTo=allowedForAll` / `deployedTo=acquiredForAll`) | **High** | Agents | Graph v1.0 `copilot/admin/catalog/packages` (`availableTo`: `packageAllowStatus`, `deployedTo`: `packageAcquireStatus`, `type`, `elementTypes`), `CopilotPackages.Read.All`. **Corrected 2026-11-05 with a live validation run.** "Microsoft-published" is decided from the package's `type` property: the live tenant returns `firstParty`/`thirdParty` (never the literal string `microsoft`), so `type == 'firstParty'` (case-insensitive) is Microsoft-published; any other `type`, including blank/null, counts as custom/external. If `type` is blank, falls back to a `publisher` allowlist (`Microsoft Corporation`, `Microsoft`, `Microsoft 365`, `Microsoft Copilot Studio`) as a secondary signal only. Packages that aren't an agent or tool by `elementTypes` (Office add-ins/tabs, the "App" kind) are excluded first, matching `chadmcox/Copilot`'s `Get-PackageKind`/`Get-AgentToolsHealth.ps1` logic. Live run found 212 flagged packages tenant-wide. | `NotAuthorized` (403 — license or consent, message names both) |

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

> **Update 2026-11-05:** all five were subsequently live-validated against an
> F7-licensed test tenant (no separate Agent 365 license needed; the Package API
> was reachable with `CopilotPackages.Read.All` alone). `.1007`'s classification
> logic was also corrected after live validation surfaced that `type` returns
> `firstParty`/`thirdParty`, not the literal `microsoft`. See each test's `.md`
> file for its validation banner.

Skills and MCP stay fully out of scope until a licensed tenant confirms the
`elementType`/package-API schema (see coverage-matrix.md's "Skills and MCP —
surface redefinition" section).

The MT.1205/MT.1208 granular split stays in the matrix exactly as currently
written (four Covered rows for MT.1208, zero-sponsor-only scope for MT.1205).

> **Update — MCP built, Topic hygiene held:** the `elementType`/package-API
> schema was live-confirmed against the F7-licensed test tenant (`AgentConnectors`/
> `MCPServers` elementTypes, per-package `elementDetails[].elements[].definition`
> JSON holding `toolSource.remoteMcpServer.mcpServerUrl`). This unblocked two
> findings, both built and live-validated this round:
> - `MP.AIGOV.1008` — G20, MCP server endpoint reachable over plain `http://`.
>   Graph-only (`CopilotPackages.Read.All`), not Defender-dependent as the
>   matrix originally assumed. 37/37 live MCP packages were `https://`.
> - `MP.AIGOV.1009` — G14a, blueprint client secret nearing expiration (a
>   configurable `WarningDays` warning window, default 30, explicitly excluding
>   already-expired secrets since that's MT.1208's job).
>
> G21 (MCP server on a non-Microsoft host) was investigated and **dropped**:
> live data showed 37/37 MCP connectors in the test tenant are on non-Microsoft
> SaaS hosts, which is inherent to using third-party tools, not an anomaly, and
> fully overlaps with `.1007`'s custom/external classification — no
> differentiating signal.
>
> G12–G14 (Topic hygiene via Dataverse) remain **held**: `botcomponent`'s
> schema was confirmed from Microsoft Learn docs alone (`componenttype=9` is
> "Topic (V2)", `createdon`/`modifiedon`/`data` are real fields), but live
> Dataverse access to this test tenant requires an interactive Azure sign-in
> that isn't available in this environment, and G13 (topic scope boundary)
> additionally depends on an undocumented JSON property inside the opaque
> per-topic `data` blob. All three are deferred until a live Dataverse
> connection can validate the design — not built this round.

**Optional, not required for Phase 2 to start:** draft an upstream issue against
`maester365/maester` for the declared-vs-shipped severity mismatch found in both
`Test.MT.1118.ps1` (declared `Medium`, emits `Severity 'High'`) and
`Test.MT.1208.ps1`'s first condition (same pattern).

## Decisions already made (carried over, not re-asked)

- Pack code: `AIGOV` — checked `packs.maester.cloud`'s public index; unclaimed.
- Repo created: `chadmcox/maester-ai-governance-pack`, public, MIT license.
- Billing excluded from the pilot (still in the matrix as Gaps).
- Revision 2 approved for Phase 2, with the fixes in this document applied.
