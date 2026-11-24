# How each check works

This page holds the details behind each check: what it reads, the exact pass and fail rules, its settings, and
the notes from live and seeded test runs. The test pages in the Maester report only say why each check matters
and how to fix it.

<a id="mp-aigov-1001"></a>

## MP.AIGOV.1001: Agent catalog adoption is below a configurable threshold over the D90 report period

> [!NOTE]
> **Validated** 2026-11-05 against a real Microsoft 365 test tenant (F7-licensed; the package
> catalog API was reachable with `CopilotPackages.Read.All` alone — no separate Agent 365 license
> was required to reach it in this tenant). The run correctly **Skipped** with
> "the package catalog reports no agents, so adoption has nothing to measure" because this tenant's
> catalog had zero agents. The adoption-threshold comparison itself was not exercised; re-validate
> that branch once a tenant with at least one agent and usage data is available.

Checks whether Microsoft 365 Copilot agent catalog adoption is at or above a configurable threshold
(default 5%) over the fixed D90 report period. Only runs when the package catalog reports at least
one agent. Skips when fewer than 20 users are reported, or when no usage-report column matches the
undocumented `*Agent*Activity*` name pattern.

Low adoption after agents have been published for a while can mean the agents solve the wrong
problem, are hard to find, or were never announced to the people they were built for.

<a id="mp-aigov-1002"></a>

## MP.AIGOV.1002: Blocked package has an open pending install or consent request

> [!NOTE]
> **Validated** 2026-11-05 against a real Microsoft 365 test tenant (F7-licensed; the package
> catalog API was reachable with `CopilotPackages.Read.All` alone). The run correctly **Passed**:
> no blocked package had an open pending install or consent request. The `requestStatus`/
> `requestType` field names matched the live schema.

Checks whether a package the tenant has blocked (`isBlocked`) still has an open pending install or
consent request (`requestStatus`/`requestType`). A pending request against a blocked package means a
user can still be waiting on, or an admin can still approve, an install the tenant already decided to
block.

<a id="mp-aigov-1003"></a>

## MP.AIGOV.1003: Agent is assigned directly to users instead of via a group

> [!NOTE]
> **Validated** 2026-11-05 against a real Microsoft 365 test tenant (F7-licensed; the package
> catalog API was reachable with `CopilotPackages.Read.All` alone). The run correctly **Failed**
> (true positive), finding 1 real package ("Copilot Code") with a directly assigned user. The
> per-package detail call's `allowedUsersAndGroups`/`acquireUsersAndGroups` field names and
> `resourceType` values matched the live schema. This test is slow (iterates every package's detail
> individually) — expect several minutes against a catalog with hundreds of packages.
>
> Nov 18, 2026: a throttled run passed even though some package reads had failed. Fixed: unread packages are now
> counted. If none can be read the test skips with an error; if the rest are clean it skips as a partial check;
> beside a finding it notes how many weren't read.

Checks whether an agent is assigned directly to individual users instead of through a group. The
audience collections (`allowedUsersAndGroups`, `acquireUsersAndGroups`) are only returned by the
per-package detail call (`GET /copilot/admin/catalog/packages/{id}`) — the list call does not return
them, so this test reads every package's detail individually. A direct user assignment has no group
to audit membership through and no single place to see who has access.

<a id="mp-aigov-1004"></a>

## MP.AIGOV.1004: Agent identity, blueprint, or blueprint principal has exactly one sponsor and zero owners (Preview)

> [!NOTE]
> **Validated** 2026-11-05 against a real Microsoft 365 test tenant (Graph only, no Agent 365
> license). The run correctly found 10 real Agent Identity / Agent Identity Blueprint objects with
> exactly one sponsor and zero owners, with accurate object IDs, display names, and object types in
> the result table.

Checks every Agent Identity, Agent Identity Blueprint, and Blueprint Principal for exactly one
assigned sponsor and zero owners. A sponsor provides organizational accountability for why the agent
exists; an owner can administer the object itself. An object with one sponsor and no owners is a
single point of failure: if that one person leaves or is disabled, nobody with a formal relationship
to the object remains.

Graph only — this test does not need a Microsoft Agent 365 license.

<a id="mp-aigov-1005"></a>

## MP.AIGOV.1005: Classic Copilot Studio service principal has no corresponding Agent ID registration (Preview)

> [!NOTE]
> **Validated** 2026-11-05 against a real Microsoft 365 test tenant (Graph only, no Agent 365
> license). The run passed clean: no classic Copilot Studio service principal in the test tenant was
> missing an Agent Identity or Blueprint Principal registration.

Checks for classic Copilot Studio service principals — tagged `AgentCreatedBy:CopilotStudio`,
`AgenticApp`, `AIAgentBuilder`, `AgenticInstance`, or a `power-virtual-agents-*` tag — that have no
corresponding Agent Identity or Agent Identity Blueprint Principal registration. This describes a
current state, not a required migration: Microsoft has not published an in-place way to convert a
classic service principal into an Agent ID.

Graph only — this test does not need a Microsoft Agent 365 license.

<a id="mp-aigov-1006"></a>

## MP.AIGOV.1006: Agent display name or description is empty or a placeholder value

> [!NOTE]
> **Revalidated** Nov 18, 2026: correctly **Failed** (true positive), reporting three agents built
> in this tenant with missing or placeholder metadata under the revised ownership scope.

> [!NOTE]
> **Validated** 2026-11-05 against a real Microsoft 365 test tenant (F7-licensed; the package
> catalog API was reachable with `CopilotPackages.Read.All` alone). The initial run against the live
> schema **errored**: `description` is not a valid property on `microsoft.graph.copilotPackageDetail`
> (Graph returned HTTP 400). The real fields are `shortDescription` and `longDescription`. The test
> was fixed to select and check both fields (empty counts only if both are blank), then re-run and
> correctly **Failed** (true positive), finding 3 real packages with an empty description.

> **Revised** 2026-11-11: now checks only packages built in this tenant (`type` not firstParty,
> microsoft, thirdParty or external). A live run flagged vendor catalog entries such as "Box" and
> "Coachello", whose names and descriptions only the vendor can change. Re-validation pending.

Checks whether an agent built in this tenant has an empty display name or description, or whether the display name matches
a placeholder pattern (test, demo, copy, draft, untitled, and similar). Without a clear name and
description, reviewers and users have nothing to judge the agent's purpose by.

<a id="mp-aigov-1007"></a>

## MP.AIGOV.1007: Custom or external package is available or deployed tenant-wide

> [!NOTE]
> **Validated** 2026-11-05 against a real Microsoft 365 test tenant (F7-licensed; the package
> catalog API was reachable with `CopilotPackages.Read.All` alone, so this endpoint may require a
> Microsoft Agent 365 license depending on tenant). The run correctly **Failed** (true positive),
> finding 212 real custom/external packages available or deployed tenant-wide (for example
> "Tavily", "SAP Joule", "Creately"). Sampled packages showed `type: thirdParty` with varied
> `elementTypes` (for example `AgentSkills;AgentConnectors;DeclarativeCopilots;ToolPlugins` for
> "Moody's Credit MCP", and `DeclarativeCopilots;AgentConnectors;MCPServers` for "Tavily"). Three
> Microsoft-published packages ("Sales", "Service", "Frontline Agent (Preview)") were observed with
> `type: firstParty`, not the literal string `microsoft` — the classification below uses the
> observed `firstParty` value instead of assuming a different literal.

Checks whether a custom or external (non-Microsoft-published) package is available or deployed
tenant-wide (`availableTo` indicating `allowedForAll`, or `deployedTo` indicating `acquiredForAll`).
A package is treated as Microsoft-published when its `type` property equals `firstParty`
(case-insensitive); any other value — including a blank or null one — counts as custom/external. If
`type` itself is missing, the check falls back to an explicit `publisher` allowlist (`Microsoft
Corporation`, `Microsoft`, `Microsoft 365`, `Microsoft Copilot Studio`) as a secondary signal.
Packages that aren't an agent or a tool by `elementTypes` (Office add-ins and tabs, i.e. the "App"
kind) are out of scope and excluded before the custom/external check runs. A custom or external
agent going out to the whole tenant by default skips the deliberate, scoped rollout that kind of
agent should get.

<a id="mp-aigov-1008"></a>

## MP.AIGOV.1008: MCP server endpoint should not be reachable over plain HTTP

> [!NOTE]
> **Validated** 2026-11-06 against a real Microsoft 365 test tenant (F7-licensed), and re-validated
> after adding scheme/host-only redaction and failure counting. The run correctly **Passed** (true
> negative): 37 packages had an MCP server element, and all 37 observed `mcpServerUrl` values were
> `https://` (sample hosts: `mcp.maestrolabs.com`, `mcp.tavily.com`, `mcp.asana.com`, `mcp.xero.com`,
> `mcp.factset.com`). This confirms the `elementDetails` `AgentConnectors` schema and the
> URL-scheme check both work; a zero-finding result here is the expected negative case for this
> tenant, not evidence the check is broken. The redaction and failure-counting logic ran without
> error, but no package in this tenant triggered a detail-call or parse failure, so that specific
> code path has not been exercised live.

Checks whether any MCP server endpoint referenced by an installed package is reachable over plain
`http://` instead of `https://`. The URL comes from the per-package detail call (`GET
/copilot/admin/catalog/packages/{id}`), specifically the `elementDetails` entry with `elementType`
`AgentConnectors`, whose `elements[].definition` (a JSON string) contains
`toolSource.remoteMcpServer.mcpServerUrl`. An agent calling an MCP server over plain HTTP sends tool
inputs and outputs — which may include sensitive data pulled into the conversation — without
transport encryption, exposing them to interception on the network path.

The result table never shows the full `mcpServerUrl`: only the scheme and host (e.g.
`http://example.com`) are reported, since the path, query, fragment, and any embedded userinfo may
carry tenant- or tool-specific identifiers. If a package's detail call or definition parse fails,
it is counted but does not fail the whole test; the result notes how many packages could not be
evaluated. If every package with an MCP server element fails to evaluate, the test skips with
`Error` rather than reporting a false pass.

<a id="mp-aigov-1009"></a>

## MP.AIGOV.1009: Agent Identity Blueprint credential should not be nearing expiration

> [!NOTE]
> **Revalidated** Nov 18, 2026: correctly **Failed** (true positive), with one credential inside the
> 30-day window. Independent reads found two active secrets and no certificates. One secret now
> has about 30 days remaining versus 42 days at the earlier validation date, consistent with elapsed
> time rather than changed test logic.

> [!NOTE]
> **Validated** 2026-11-06 against a real Microsoft 365 test tenant (F7-licensed), and re-validated
> after adding certificate (`keyCredentials`) support. The run correctly **Passed** (true
> negative): 6 Agent Identity Blueprints were found, 2 of which have an active client secret, and
> neither secret falls within the 30-day warning window. This confirms the
> `applications/microsoft.graph.agentIdentityBlueprint` read and the already-expired exclusion both
> work; a zero-finding result here is the expected negative case, not evidence the check doesn't
> run. No blueprint in this tenant had a `keyCredentials` entry, so the certificate code path ran
> without error but has not been exercised against an actual certificate credential.

Checks whether any Agent Identity Blueprint client secret or certificate credential is still active
but will expire within a configurable warning window (default 30 days). Both `passwordCredentials`
(secrets) and `keyCredentials` (certificates) are checked; the result table includes a `Type`
column distinguishing the two. Maester's own `MT.1208` flags credentials that are
already expired, valid for more than 730 days, exceed a maximum active-secret count, or are
retained alongside a federated identity credential — confirmed by reading its full source — but has
no forward-looking warning before a still-active credential actually expires. This test fills that
gap. An already-expired credential is `MT.1208`'s finding, not this one's; this test explicitly
excludes any `endDateTime` in the past.

<a id="mp-aigov-1010"></a>

## MP.AIGOV.1010: MCP server should be hosted on an allowlisted domain

Checks whether any MCP server endpoint referenced by an installed package is hosted on a domain
outside a configurable allowlist (`-AllowedHosts`). The URL comes from the per-package detail call
(`GET /copilot/admin/catalog/packages/{id}`), specifically the `elementDetails` entry with
`elementType` `AgentConnectors`, whose `elements[].definition` (a JSON string) contains
`toolSource.remoteMcpServer.mcpServerUrl`. A host matches the allowlist if it equals an entry
exactly or is a subdomain of one.

The default allowlist covers common Microsoft domains only. Every third-party vendor your tenant
has approved should be added to the allowlist explicitly — until then, this check reports them as
unreviewed. The result table never shows the full `mcpServerUrl`: only the scheme and host are
reported, matching `MP.AIGOV.1008`'s redaction. Detail-call and definition-parse failures are
counted the same way as `MP.AIGOV.1008`: a partial failure is noted in the result, and a total
failure skips with `Error` instead of reporting a false pass.

> [!NOTE]
> **Validated** 2026-11-06 against a real Microsoft 365 test tenant (F7-licensed). With the default
> (Microsoft-only) allowlist, the run correctly **Failed** (true positive): all 37 packages with an
> MCP server element resolved to a non-Microsoft host (no Microsoft-hosted MCP server exists in this
> tenant today). This is expected for an unreviewed allowlist, not evidence of a broken check — add
> each reviewed vendor host to `-AllowedHosts` as it's approved.

<a id="mp-aigov-1011"></a>

## MP.AIGOV.1011: MCP tool with a destructive or open-world effect should not be in a tenant-wide package

Checks whether any MCP tool with a `destructiveHint` or `openWorldHint` annotation is reachable
through a package that's available or deployed tenant-wide (`availableTo` indicating
`allowedForAll`, or `deployedTo` indicating `acquiredForAll` — the same tenant-wide signal
`MP.AIGOV.1007` uses). The tool annotations come from the per-package detail call (`GET
/copilot/admin/catalog/packages/{id}`), specifically the `elementDetails` entry with `elementType`
`AgentConnectors`, whose `elements[].definition` (a JSON string) contains
`toolSource.remoteMcpServer.mcpToolDescription.tools[].annotations`.

A `destructiveHint: true` tool can make an irreversible change; an `openWorldHint: true` tool can
interact with an open-ended, not-fully-enumerable set of external entities. Either one, combined
with the tool being reachable by everyone in the tenant by default, is materially riskier than the
same tool scoped to a reviewed pilot group. Detail-call and definition-parse failures are counted
the same way as `MP.AIGOV.1008`/`MP.AIGOV.1010`: a partial failure is noted in the result, and a
total failure skips with `Error` instead of reporting a false pass.

> [!NOTE]
> **Live rerun** Nov 18, 2026 **Passed** with zero tenant-wide MCP candidates. Both reachable MCP
> packages were group-scoped. This vacuous negative does not re-exercise the previously documented
> tenant-wide annotation finding; current catalog scope differs from the earlier banner.

> [!NOTE]
> **Validated** 2026-11-06 against a real Microsoft 365 test tenant (F7-licensed). The run
> correctly **Failed** (true positive): found MCP tools with `openWorldHint: true` inside a
> tenant-wide package ("Moody's Credit MCP", `type: thirdParty`, `availableTo: allowedForAll`),
> confirming both the tenant-wide filter and the tool-annotation schema work against real data.

<a id="mp-aigov-1012"></a>

## MP.AIGOV.1012: Agent skill should have a clear description, and should not be exposed to Copilot tenant-wide without review

Checks whether an agent skill (the `SKILL.md`-style packaging described by Microsoft's Copilot
Cowork plugin guide, confirmed as a real `elementTypes` value: `AgentSkills`) has a weak frontmatter
description, or is exposed to Copilot inside a package that's available or deployed tenant-wide. The
skill definition comes from the per-package detail call (`GET
/copilot/admin/catalog/packages/{id}`), specifically the `elementDetails` entry with `elementType`
`AgentSkills`, whose `elements[].definition` (a JSON string) contains `expose_skill_to_copilot`
(boolean) and `frontmatter.{name,description}`.

A skill is flagged if either condition holds:

- Its `frontmatter.description` is empty or shorter than a configurable `-MinDescriptionLength`
  (default 40 characters). Copilot uses this text to decide when to invoke the skill, so a missing
  or vague one risks it firing on the wrong request, or never firing at all.
- `expose_skill_to_copilot` is `true` **and** the package is available or deployed tenant-wide (the
  same signal `MP.AIGOV.1007` and `MP.AIGOV.1011` use). A skill explicitly exposed to Copilot,
  reachable by everyone by default, should get the same deliberate, scoped rollout review as any
  other tenant-wide tool.

Detail-call and definition-parse failures are counted the same way as `MP.AIGOV.1008`/
`MP.AIGOV.1010`/`MP.AIGOV.1011`: a partial failure is noted in the result, and a total failure skips
with `Error` instead of reporting a false pass.

> [!NOTE]
> **Validated** 2026-11-06 against a real Microsoft 365 test tenant (F7-licensed). The run
> correctly **Failed** (true positive) against real data: 32 packages had an agent skill element,
> confirming the `AgentSkills` `elementDetails` schema (`folder`, `expose_skill_to_copilot`,
> `frontmatter.{name,description}`) against a real skill ("Moody's Credit MCP"'s "earnings-brief"
> skill).

<a id="mp-aigov-1013"></a>

## MP.AIGOV.1013: Enabled spending policy should have a credit ceiling

> [!NOTE]
> **Validated** 2026-11-06 against a real Microsoft 365 test tenant (F7-licensed), via an actual
> `Invoke-Maester` run (not just a manual query). The run correctly **Failed** (true positive): all 8
> currently-enabled Copilot spending policies had an unlimited `periodLimit`
> (`#microsoft.graph.unlimitedCostManagementQuantity`). This surface is reachable with
> `CopilotCostManagement-Policy.Read.All` alone and is delegated-permission only — Microsoft Learn
> lists Application permission type as not supported for this endpoint.

Checks whether an enabled Copilot spending policy has no overall credit ceiling. A policy's
`periodLimit` is an `@odata.type`-discriminated `costManagementQuantity`: either
`#microsoft.graph.limitedCostManagementQuantity` (a real numeric `value` cap) or
`#microsoft.graph.unlimitedCostManagementQuantity` (no cap at all). A `disabled` policy is not
currently in effect and is excluded. An unbounded policy has no ceiling to catch runaway
Copilot/agent consumption, regardless of how tightly its audience is scoped — the per-user limit
alone does not bound total tenant spend under that policy.

<a id="mp-aigov-1014"></a>

## MP.AIGOV.1014: Group backing a spending policy should have owners and a description

> [!NOTE]
> **Validated** 2026-11-06 against a real Microsoft 365 test tenant (F7-licensed), via an actual
> `Invoke-Maester` run. The run correctly **Failed** (true positive): all 8 distinct groups backing
> an enabled, group-scoped spending policy had zero owners, and several also had no `description`.
> Reading `assignedGroups` needs `CopilotCostManagement-Assignment.Read.All`; reading group owners and descriptions needs the
> standard `Group.Read.All` (or `Directory.Read.All`). Both are delegated-permission surfaces for
> this endpoint — Microsoft Learn lists Application permission type as not supported.

Checks whether a group backing a `selectedGroupsSpendingPolicy` has fewer than a configurable
minimum number of owners (default 2) or a blank `description`. Only groups assigned to a currently
`enabled` policy are evaluated. A spending-policy audience with no one accountable for its
membership, or no recorded reason for its existence, is itself a governance gap, independent of
anything about the policy's own settings — this complements MP.AIGOV.1013 and MP.AIGOV.1015, which
check the policy configuration rather than the audience that configuration applies to.

<a id="mp-aigov-1015"></a>

## MP.AIGOV.1015: Spending policy cap should not be overridden by a more permissive overlapping policy

> [!NOTE]
> **Revalidated** Nov 18, 2026: **Passed** (true negative) with 21 enabled policies and 21
> audiences checked. No more-permissive overlapping cap was reported under the revised scope.

> [!NOTE]
> **Validated** 2026-11-09 against a real Microsoft 365 test tenant (F7-licensed), via an actual
> `Invoke-Maester` run of this revised (most-permissive-policy-wins) version. The run correctly
> **Passed** (true negative): across 8 enabled spending policies and 8 audiences checked, no
> audience's per-user cap was overridden by a more permissive overlapping policy. This is a
> well-formed negative, not evidence the overlap condition can't occur — a tenant that assigns a
> group to two policies with different per-user limits would be flagged.

When more than one spending policy applies to a person, the most permissive one is enforced: the higher
limit applies, and limits from overlapping policies aren't added together. A lower per-user cap in an
overlapping policy therefore does nothing for the people it overlaps with.

This test reads every enabled spending policy. For each group in an enabled group-scoped policy, plus the
"All users" audience of any enabled all-users policy, it lists every policy that applies, works out the
effective per-user limit (Unlimited beats any cap; otherwise the highest cap wins) and reports:

| Severity | Condition |
| --- | --- |
| High | A policy's per-user cap is overridden by a policy with an unlimited per-user limit. |
| Medium | A policy's per-user cap is overridden by a policy with a higher per-user cap. |
| Low | Redundant overlap (two or more group-scoped policies with the same limit), or limits that can't be compared (missing, unreadable, or in different units). |

A group-scoped policy that is **more** permissive than an all-users base policy is the normal tiering
pattern (for example, everyone gets 100 credits and a pilot group gets 1,000) and is not reported.

Resource-scoped spending policies (Specific resource / Resource collection) aren't exposed by Graph yet,
so overlaps between a resource policy and an identity policy aren't evaluated. Resource policies take
precedence over identity policies for the agents and environments they cover; review them manually in the
Microsoft 365 admin center.

<a id="mp-aigov-1016"></a>

## MP.AIGOV.1016: MCP server should not use weak or no authentication

Checks each MCP server's `toolSource.remoteMcpServer.authorization.type`, read from the same
per-package detail call (`GET /copilot/admin/catalog/packages/{id}`) and JSON path
`MP.AIGOV.1008`/`MP.AIGOV.1010`/`MP.AIGOV.1011` already use. The documented values (Learn:
["Configure remote MCP servers for Microsoft 365 Copilot plugins"](https://learn.microsoft.com/microsoft-365/copilot/extensibility/configure-plugin-mcp-servers))
are `None`, `OAuthPluginVault`, `ApiKeyPluginVault`, `DynamicClientRegistration`, `AzureKeyVault`,
and `ConnectionVault` (developer preview) — not literal strings like "anonymous" or
"shared-secret". This test reports every distinct value it actually sees in the tenant before
classifying anything, so an unexpected or newly introduced value is visible rather than silently
bucketed.

Classification: `None` is **High** — the server declares no authentication at all. A missing or
unparseable `authorization` object (no type in the manifest at all, rather than a well-formed
object whose type is the documented literal `None`) is reported separately as **Unspecified**, also
**High** — neither represents an enforced identity flow, but an admin reviewing the observed-values
list should be able to tell a deliberately anonymous MCP server from one whose manifest is missing
or malformed. `ApiKeyPluginVault` and `AzureKeyVault` are **Medium** — both ultimately
authenticate with a stored static secret rather than an identity-based token flow; `AzureKeyVault`
only changes where that secret is stored. `ConnectionVault` (developer preview) is treated the same
as `AzureKeyVault` pending broader documentation. `OAuthPluginVault` and
`DynamicClientRegistration` are a pass — both are Entra/OAuth identity flows. Any finding is
reported as worse when its package is available or deployed tenant-wide, using the same
`availableTo`/`deployedTo` signal as `MP.AIGOV.1007`/`MP.AIGOV.1011`. Only the MCP server's scheme
and host are ever reported, never the full `mcpServerUrl`, matching `MP.AIGOV.1008`. Detail-call and
definition-parse failures are counted the same way as those tests: a partial failure is noted in
the result, and a total failure skips with `Error` instead of reporting a false pass.

> [!NOTE]
> **Validated** 2026-11-10 against a real Microsoft 365 test tenant (F7-licensed), after fixing a
> false-negative bug: the candidate filter matched only the literal `elementTypes` string
> `MCPServers`, which missed real MCP-backed packages (LawQi, LegalZoom) whose `elementTypes` carry
> `AgentConnectors` instead. A unit test reproduces that exact shape and a package explicitly
> declaring `authorization.type: "None"`, asserting a High finding. The filter now matches either
> `MCPServers` or `AgentConnectors` (73 candidates vs. the old 40), with a separate confirmed-MCP
> count tracked from the actual per-element `toolSource.remoteMcpServer` payload.
>
> Live, the run correctly **Passed**: only 2 of the 73 candidates are reachable by users --
> `Sales` and `Service`, both Microsoft first-party packages whose MCP element has no
> `authorization` block at all (`Unspecified`), correctly suppressed as platform-authenticated per
> this test's own classification rule. 71 candidates were skipped as blocked or allowed-for-no-one,
> including LawQi and LegalZoom: both are genuine MCP-backed packages with
> `authorization.type: "None"` (confirmed via a direct detail-call read), but this tenant's catalog
> now has them set to `allowedForNone` (they were `allowedForAll` in an earlier run), so the
> High finding they would otherwise produce could not be re-exercised live this run. That reachable
> state is a tenant-data change, not a property of this fix; the unit test is what proves the fix
> itself against that exact package shape.

<a id="mp-aigov-1017"></a>

## MP.AIGOV.1017: Conditional Access should cover agent identities

Checks whether any enabled Conditional Access policy targets agent identities. Reads `GET
/identity/conditionalAccess/policies` (`graph-rest-beta` — the properties below do not exist on the
v1.0 `conditionalAccessClientApplications` or `conditionalAccessConditionSet` resources, confirmed
by comparing the beta and v1.0 schema reference pages). A policy "targets agent identities" when its
`conditions.clientApplications.includeAgentIdServicePrincipals` is non-empty, its
`conditions.clientApplications.agentIdServicePrincipalFilter.rule` is set, or its
`conditions.agentIdRiskLevels` is non-empty.

Reports three independent outcomes:

- **Full pass**: at least one enabled policy targets agent identities dynamically, via
  `agentIdServicePrincipalFilter` or `agentIdRiskLevels`, so current and future agent identities are
  automatically covered.
- **Partial coverage (Medium)**: enabled policies target agent identities, but only by a static
  `includeAgentIdServicePrincipals` ID list — no filter or risk condition. There is no "All"
  sentinel value for this property (confirmed against the `conditionalAccessClientApplications` beta
  schema reference), so a newly created agent identity is not automatically covered until an admin
  adds its ID to the policy.
- **No coverage (High)**: either no policy targets agent identities at all, or agent-targeting
  policies exist but every one has `state` `disabled` or `enabledForReportingButNotEnforced`
  (report-only), so none is actually enforced.

This intentionally does not duplicate `MT.1181` ("Conditional Access policy is present that blocks
high agent risk sign-ins"), confirmed by reading its source
(`Test-MtCaAgentRiskBlockPolicy.ps1`): `MT.1181` checks the narrow case of
`conditions.agentIdRiskLevels` containing `high` **and** `grantControls.builtInControls` containing
`block` on an enabled policy. This test is broader and upstream of that one — it flags a tenant with
no agent-identity Conditional Access coverage at all, regardless of control type. A tenant where
`MT.1181` passes will also pass this test's condition (a), since a block-on-high-risk policy also
targets agent identities via `agentIdRiskLevels`. But a tenant that targets agent identities only
with a non-block control, or only in report-only mode, is still flagged here even though it falls
outside `MT.1181`'s narrower scope.

> [!NOTE]
> **Validated** 2026-11-06 against a real Microsoft 365 test tenant (F7-licensed). The run
> correctly **Passed** (true negative): of 57 total Conditional Access policies, 6 enabled
> policies already target agent identities, so condition (a) does not apply. This run also
> caught and fixed a wrong endpoint path (`identity/conditionalAccessPolicies` instead of the
> correct `identity/conditionalAccess/policies`), confirming the request is well-formed against
> real data, not just schema documentation.

<a id="mp-aigov-1018"></a>

## MP.AIGOV.1018: Agent identity currently at risk should be remediated or dismissed

Checks `GET /identityProtection/riskyAgents` (`graph-rest-beta` — confirmed via the
`Microsoft.Graph.Beta.Identity.SignIns` PowerShell module reference as the documented endpoint for
this resource; no v1.0 equivalent exists today). The `riskyAgent` resource carries `riskState`
(`none`, `confirmedSafe`, `dismissed`, `atRisk`, `confirmedCompromised`, `unknownFutureValue`),
`agentDisplayName`, `riskLevel`, `riskDetail`, `isEnabled`, and `isDeleted`.

"At risk and not yet remediated or dismissed" maps specifically to `riskState eq 'atRisk'`:
`confirmedSafe` and `dismissed` are both post-investigation resolved states. `confirmedCompromised`
agents are listed separately in the result (never silently dropped) but don't drive this finding's
title, since they represent an already-confirmed worse state rather than an unremediated pending
one.

Uses the least-privileged permission confirmed in the Microsoft Graph permissions reference,
`IdentityRiskyAgent.Read.All` — a distinct permission from `IdentityRiskyServicePrincipal.Read.All`,
which covers a different, non-agent resource. The Learn page for this feature currently states
Identity Protection for agents will require a Microsoft Agent 365 license "starting soon" (not
required at the time this test was written).

A 403 is reported as `NotAuthorized` with a message calling out the `IdentityRiskyAgent.Read.All`
permission and the possibility that this tenant has already started requiring a Microsoft Agent 365
license. A 404 is reported separately (also skipped, not a pass) with a message noting the beta
endpoint may not yet be rolled out in this tenant, or Identity Protection for agents may not be
enabled — distinct from an unrelated failure, which still skips with the generic `Error` path.

> [!NOTE]
> **Validated** 2026-11-06 against a real Microsoft 365 test tenant (F7-licensed), after the user
> pre-consented the `IdentityRiskyAgent.Read.All` scope. The run correctly **Passed** (true
> negative): `GET /identityProtection/riskyAgents` returned 0 records in this tenant, so neither
> the `atRisk` nor `confirmedCompromised` paths were exercised against real data this round.

<a id="mp-aigov-1019"></a>

## MP.AIGOV.1019: Agent identity should not have user-consented delegated permissions

Lists agent identities via `GET /servicePrincipals/microsoft.graph.agentIdentity` (v1.0), then for
each one calls `GET /oauth2PermissionGrants?$filter=clientId eq '{agent identity object ID}' and
consentType eq 'Principal'` (v1.0) — `clientId` is the service principal's object ID, not its
`appId`, and `$filter` on this endpoint only supports `eq`, confirmed against the
`oauth2PermissionGrant` resource and "List oauth2PermissionGrants" Learn reference pages.
`consentType` `Principal` means a single end user consented for themselves, as opposed to
`AllPrincipals` (an administrator consented tenant-wide) — this test only reports the
user-consented case, since an admin-consented grant is a deliberate, reviewed decision rather than
an individual user's choice to grant an autonomous agent delegated access to their own data. Uses
the least-privileged Graph permission confirmed on the "List oauth2PermissionGrants" reference page,
`Directory.Read.All` (application).

Findings are grouped per agent identity: the number of distinct consenting users and the
deduplicated set of granted scopes. An agent is **Medium** by default; **High** if any granted scope
appears on Maester's own `MT.1223` (`Test-MtEntraAgentHighRiskGraphPermissions`) high-risk
permission list. That list was read directly from `MT.1223`'s source
(`Get-MtEntraAgentHighRiskGraphPermissionFinding.ps1`, pinned commit
`616559854634e5150dbde69850c4224191635bb1` — the same commit this pack's `Test-MtPack` CI job builds
Maester from) rather than re-derived from memory, so it tracks Maester's actual classification
instead of a separate guess at what counts as high risk. That hashtable isn't exported from the
module, so it is reproduced here verbatim with this citation; keep it in sync if `MT.1223`'s source
changes.

A Pester unit test (`unit-tests/Test.MP.AIGOV.1019.Tests.ps1`) pins a SHA-256 hash of the
`$HighRiskScopes` array literal as a drift tripwire: if a future edit changes that array without a
matching update to the pinned hash and the commit SHA cited above, the unit test fails rather than
silently drifting from Maester's current classification.

An agent identity whose per-agent grant read fails (not a 403 on the initial list call, but a
failure reading grants for one specific agent) is counted and excluded from the result rather than
silently dropped or failing the whole test — the count is reported alongside a Pass or Fail outcome
so a partial-evaluation result is never mistaken for a clean Pass.

> [!NOTE]
> **Validated** 2026-11-06 against a real Microsoft 365 test tenant (F7-licensed). The run
> correctly **Passed** (true negative): 11 agent identities were checked and none had a
> user-consented (non-admin) delegated permission grant, so the High-severity path (a scope on
> MT.1223's high-risk list) was not exercised against real data this round.

<a id="mp-aigov-1020"></a>

## MP.AIGOV.1020: Custom agent or tool that nobody uses should be blocked or removed

> [!NOTE]
> **Revalidated** Nov 18, 2026: **Passed** (true negative) for three reachable custom agents/tools.
> This confirms the revised reachability scope below no longer reports the former unreachable
> finding; the change is not evidence that the earlier unused object became active.

> [!NOTE]
> **Validated** 2026-11-09 against a real Microsoft 365 test tenant, via an actual `Invoke-Maester` run.
> The run correctly **Failed** (true positive): one custom agent ("Vani") was never used and hadn't been
> modified in over 180 days. The package-detail `activeUsers` and `lastUsedDateTime` properties read and
> typed as expected.

> **Revised** 2026-11-11: now checks only packages people can reach (not blocked, and `availableTo` not
> allowedForNone). "Vani" from the validation run was available to no one, so there was nothing to block;
> it no longer fires. Re-validation pending.

Finds custom or external agents and tools in the Copilot catalog that nobody uses: people can reach them, no active
users in the last 30 days, last used more than `StaleDays` ago (or never), and not changed in `StaleDays`.
`StaleDays` defaults to 180, matching Maester's own dormancy tests; 90 is a stricter option.
Microsoft-published packages and App-kind packages (Office add-ins, tabs) aren't checked.

Unused agents and tools keep their permissions and data access. Blocking or removing them shrinks what a
compromise or a mistake can reach.

<a id="mp-aigov-1021"></a>

## MP.AIGOV.1021: Group an agent or tool is assigned to should exist, have two owners and a description

> [!NOTE]
> **Live rerun** Nov 18, 2026 **Failed**, reporting seven assigned-group problems. Unlike the prior
> vacuous pass, current input includes assigned groups. This PR did not change this test's code;
> without historical raw snapshots, the tenant-change history cannot be independently established.

> [!NOTE]
> **Validated** 2026-11-09 against a real Microsoft 365 test tenant, via an actual `Invoke-Maester` run.
> The run correctly **Passed**: no agent or tool in this tenant is assigned to a group, so this is a
> vacuous true negative — the deleted-group, owner-count and description checks themselves weren't
> exercised against a real group assignment.

Checks the groups that agents and tools are assigned to (who can use or install them). Each group decides
who gets the agent, so someone has to own its membership.

| Severity | Condition |
| --- | --- |
| Medium | An assigned group no longer exists. |
| Medium | An assigned group has fewer than `MinOwnerCount` owners (default 2). |
| Low | An assigned group has no description. |

Agents assigned directly to users are `MP.AIGOV.1003`.

<a id="mp-aigov-1022"></a>

## MP.AIGOV.1022: Agent identity should not hold broad Microsoft Graph write permissions

> [!NOTE]
> **Validated** 2026-11-09 against a real Microsoft 365 test tenant, via an actual `Invoke-Maester` run.
> The run correctly **Passed**: none of 19 agent identities or blueprint principals holds a broad Graph
> write permission outside MT.1223's list. `appRoleAssignments` and `oauth2PermissionGrants` read and
> typed as expected, including `consentType`. The beta `inheritedAppRoleAssignments` and
> `inheritedOauth2PermissionGrants` navigation properties also read without error for all 11 agent
> identities, but every one came back empty in this tenant — so whether an inherited grant itself carries
> `consentType` is still unconfirmed live; the code's fallback (treat a missing `consentType` as
> admin-consented) hasn't been exercised against a non-empty case.

Maester's MT.1223 reports agent identities holding the twelve Microsoft Graph permissions on its
privilege-escalation list. This test covers broad permissions outside that list, on agent identities and
agent identity blueprint principals:

| Severity | Condition |
| --- | --- |
| High | A high-privilege permission: Directory, RoleManagement, Application, AppRoleAssignment, Policy, User, Group, GroupMember, Domain or Organization ReadWrite permissions, or Mail.Send, Mail.ReadWrite, Sites.FullControl.All, Sites.ReadWrite.All, Files.ReadWrite.All, Directory.AccessAsUser.All, full_access_as_app. |
| Medium | Any other tenant-wide write permission (`*.ReadWrite.All`). |

Application permissions (including ones agent identities inherit from their blueprint) and admin-consented
delegated grants are both read. User-consented grants are `MP.AIGOV.1019`. The high-privilege list is
chadmcox/Copilot's, not Microsoft's: Microsoft's guidance is least privilege, with no fixed list.

<a id="mp-aigov-1023"></a>

## MP.AIGOV.1023: Agent identity and blueprint should have a clear name and description

> [!NOTE]
> **Validated** 2026-11-09 against a real Microsoft 365 test tenant, via an actual `Invoke-Maester` run.
> The run correctly **Failed** (true positive): 5 agent identities and blueprints were flagged for unclear
> names, including a case where the ` (Microsoft Copilot Studio)` suffix was correctly ignored and the
> remaining name ("TestEntraID") still matched the placeholder rule. Confirms the shared naming helper
> (ported from `MP.AIGOV.1006`) works against live Entra Agent ID objects.

Checks names and descriptions on Entra Agent ID objects (`MP.AIGOV.1006` does the same for catalog packages).

- **Unclear name** (agent identities and blueprints): empty, fewer than 4 characters, a placeholder word
  (test, demo, sample, sandbox, temp, tmp, copy, draft, POC, untitled, dummy, delete me, do not use), "new
  agent" or "my bot" and similar, or a trailing number or copy marker such as "Agent 2" or "(1)". The
  " (Microsoft Copilot Studio)" suffix is ignored.
- **Poor description** (blueprints): empty, under 20 characters, or the same as the name.

The word list is chadmcox/Copilot's; Microsoft recommends a naming convention but publishes no list.

<a id="mp-aigov-1024"></a>

## MP.AIGOV.1024: Classic Copilot Studio service principal should have an owner and be in use

> [!NOTE]
> **Validated** 2026-11-09 against a real Microsoft 365 test tenant, via an actual `Invoke-Maester` run.
> The run correctly **Passed**: there are no classic Copilot Studio service principals in this tenant, so
> this is a vacuous true negative. The owner check and the `reports/servicePrincipalSignInActivities`
> sign-in check weren't exercised against real data; confirm the sign-in shape once a classic
> Copilot Studio service principal exists in a test tenant.

Older Copilot Studio agents run as ordinary service principals, without the sponsor and lifecycle controls
of Agent ID. `MP.AIGOV.1005` lists them; this test checks the ones that need attention first.

| Severity | Condition |
| --- | --- |
| Medium | No owner. |
| Low | Enabled, created more than `StaleDays` ago (default 180), and no sign-in in `StaleDays` or none recorded. |

The sign-in check needs AuditLog.Read.All. If sign-in activity can't be read, it's skipped and the result
says so.

<a id="mp-aigov-1025"></a>

## MP.AIGOV.1025: Spending policy should be scoped to a group and fully configured

> [!NOTE]
> **Live rerun** Nov 18, 2026 **Passed** for 21 enabled, group-scoped, configured policies. This
> differs from the earlier three-policy findings below; the current result is consistent with the
> returned configuration, not proof of when or how those policies were changed.

> [!NOTE]
> **Validated** 2026-11-09 against a real Microsoft 365 test tenant, via an actual `Invoke-Maester` run.
> The run correctly **Failed** (true positive): 10 problems across 3 group-scoped "Test Cowork ..."
> policies (disabled status, no group linked, billing method not set, a per-user limit below the default
> 2,000-credit threshold). No `allUsersSpendingPolicy` exists in this tenant yet, so the "scope All users"
> High-severity path wasn't exercised against real data this run.

Checks that every Copilot spending policy is scoped to an existing security group and fully configured.

| Severity | Condition |
| --- | --- |
| High | The policy covers all users instead of a security group. |
| High | The policy's status isn't `enabled`. |
| High | A group-scoped policy has no group linked. |
| High | A group linked to the policy no longer exists. |
| Medium | The billing method isn't set. |
| Medium | The per-user limit is a cap below `MinPerUserCredits` (default 2,000). |

A policy with no overall ceiling is `MP.AIGOV.1013`; group owners and descriptions are `MP.AIGOV.1014`;
overlapping policies are `MP.AIGOV.1015`.

<a id="mp-aigov-1026"></a>

## MP.AIGOV.1026: Enabled spending policy should alert at least two active recipients

> [!NOTE]
> **Validated** 2026-11-09 against a real Microsoft 365 test tenant, via an actual `Invoke-Maester` run.
> The run correctly **Failed** (true positive): all 8 enabled spending policies in this tenant have no
> email alert configured. Confirms `emailThresholdSettings` reads and types as expected (`isEnabled`,
> `threshold`). No enabled policy in this tenant has an alert turned on, so the recipient-disabled and
> single-recipient paths weren't exercised against real data this run.

Checks that every enabled Copilot spending policy sends a budget alert to at least two active people.
Without a working alert, nobody hears about a policy nearing its limit until users are blocked.

| Severity | Condition |
| --- | --- |
| Medium | The policy has no email alert. |
| Medium | An alert recipient is disabled or no longer exists. |
| Low | The alert has only one recipient. |

<a id="mp-aigov-1027"></a>

## MP.AIGOV.1027: Group behind a spending policy should be a populated security group without nesting

> [!NOTE]
> **Live rerun** Nov 18, 2026 **Passed** with five informational dynamic-group notices and no
> failing group finding. The earlier nested-group finding was not reproduced in the current
> input; no test code was changed to obtain this outcome.

> [!NOTE]
> **Validated** 2026-11-09 against a real Microsoft 365 test tenant, via an actual `Invoke-Maester` run.
> The run correctly **Failed** (true positive): the group behind the "Cowork Limited" policy has a nested
> group. First live run surfaced a real bug: the beta `assignedGroups` navigation property under
> `selectedGroupsSpendingPolicy` returns HTTP 404 when `-Select` asks for a single field (`id` alone), even
> though the resource exists; asking for two or more fields (`id`, `displayName`) works. Fixed by widening
> `-Select`, with a regression unit test and the same fix applied to `MP.AIGOV.1032`.

Checks the groups linked to enabled Copilot spending policies. Microsoft documents security groups as the way
to put specific users in a spending policy.

| Severity | Condition |
| --- | --- |
| Medium | Microsoft 365 group, or not security-enabled. |
| Medium | Has nested groups. Microsoft doesn't document whether spending policies count nested members. |
| Low | Has no members. |
| Info | Dynamic group. Fine for broad audiences; for spend tiers, access packages give requested, reviewed membership. Info-only results pass. |

Owners and descriptions are `MP.AIGOV.1014`. A linked group that no longer exists is `MP.AIGOV.1025`.

<a id="mp-aigov-1032"></a>

## MP.AIGOV.1032: Spending policy groups should contain only enabled, active, licensed members

> [!NOTE]
> **Validated** Nov 18, 2026 against a real Microsoft 365 test tenant. The corrected run **Failed**
> (true positive): 30 of 5,000 evaluated members were flagged, comprising 23 stale successful sign-ins
> and seven older accounts with no recorded history. Independent reads confirmed all 30 findings.
> Of 4,976 null-history records, 4,969 were new accounts, too early to judge; none had unknown age.
> Five direct new-account reads retained null history. A tenant-wide stale-history query returned 49
> users, with no overlap among the null-history IDs. All seven older null-history accounts also retained
> null history on direct reads and were created after April 2020. Seeded origin was not established.
> The report identified 6,459 memberships beyond `MaxMembers` as unchecked; this is capped coverage,
> not proof of all tenant members. That count was memberships, not people; it now counts unique members
> and leads the result with the coverage percentage. No last-attempt fallback case was present live; unit tests cover it.
> Earlier per-user sign-in reads throttled or skipped; filtered collections now return all 5,000 records,
> including `createdDateTime`. The old null-object omission and premature empty-history findings were
> corrected with account-age checks, explicit summary counts and a last-attempt fallback.
>
> **Uncapped rerun** Nov 18, 2026 (commit `783b36e`, `AIGOV.MaxSpendingPolicyMembers` = 0): **Failed**
> (true positive). 11,445 unique members checked in about 7 minutes; the result did not start with
> "Partial coverage". 64 findings: 49 stale successful sign-ins and 15 older accounts with no recorded
> history; 11,379 accounts were too new to judge; none unknown; no last-attempt fallback. An independent
> membership recount agreed, and five direct user reads confirmed their findings.

> [!NOTE]
> **Validated** 2026-11-09 against a real Microsoft 365 test tenant, via an actual `Invoke-Maester` run.
> The run correctly **Failed** (true positive): 4 of 5 spending-policy group members were flagged
> (disabled account, guest account, missing Copilot license, stale sign-in). Confirms `serviceSettings`,
> `transitiveMembers/microsoft.graph.user` (with `assignedLicenses` and `licenseAssignmentStates`), and
> batched `users -UniqueId -Select @('id','signInActivity')` all read and type as expected; no 404 occurred
> inside that batch for the 5 real member IDs checked. First live run surfaced a real bug: the beta
> `assignedGroups` navigation property under `selectedGroupsSpendingPolicy` 404s when `-Select` asks for a
> single field (`id` alone); asking for two or more fields works. Fixed by widening `-Select`, with a
> regression unit test (same fix applied to `MP.AIGOV.1027`).

Checks the people in groups linked to enabled Copilot spending policies (including members of nested groups).
Each one reported is Medium:

- The account is disabled.
- The account is a guest.
- No successful sign-in for `InactiveDays` (default 90). When successful history is absent, use the later
  interactive or non-interactive attempt. Attempt timestamps include unsuccessful attempts and are not
  proof of successful use; successful history was not backfilled before December 1, 2023.
  If all history is blank, flag `No sign-in recorded` only when `createdDateTime` is older than the window.
  New accounts are counted as `new accounts, too early to judge`; missing age or unreadable history is
  counted as unknown, not silently treated as active. The summary includes these counts, fallback usage
  and stale activity. This needs `signInActivity` (AuditLog.Read.All and Microsoft Entra ID P1).
  If it can't be read, the check is skipped and the result says so.
- No working Microsoft 365 Copilot license, when the policy turns on a service that needs one
  (`LicensedServices`, default `cowork` and `code`). Working means the license's SKU includes a Copilot service
  plan, that plan isn't disabled, and the assignment isn't in an error state.

All-users policies aren't checked here; `MP.AIGOV.1025` reports them. At most `AIGOV.MaxSpendingPolicyMembers`
(default 5,000; `0` means no cap) unique members are checked per run, and the table shows the first 100. When
members go past the cap, the result starts with the coverage, for example "Partial coverage: checked 5000 of
11459 unique member(s) (43%)". A user in several groups counts once. A run with no findings but partial coverage
skips instead of passing, because the unchecked members could have problems. Raise the setting or set it to `0`
to check everyone; expect about one sign-in read per 15 members.
Sign-in reads use filtered collections of at most 15 IDs, with paging handled by Maester, rather than a
separate sign-in request for every member.

<a id="mp-aigov-1033"></a>

## MP.AIGOV.1033: Copilot connectors users can search should only take content from apps you govern

> [!NOTE]
> **Validated** 2026-11-10 against a real Microsoft 365 test tenant. Confirmed `GET
> /external/connections` with `-Select configuration` returns `configuration.authorizedAppIds` as
> documented. The tenant has exactly one synced connection (`state: draft`), which the run correctly
> excluded from scope and counted ("1 draft or obsolete connection(s) skipped") -- the run correctly
> **Passed** (true negative: zero searchable connectors, inventory table empty). The Medium/Low
> findings paths (missing or foreign-owned service principal, `limitExceeded`, no description)
> were not exercised against real data this run; re-validate those once a `ready` or
> `limitExceeded` connection exists in the tenant.

Checks the synced (indexed) Copilot connectors that users can search, read from
`GET /external/connections`. A connection is in scope when its `state` is `ready`, or `limitExceeded`
(the index is full, but what's already indexed is still searchable). Draft and obsolete connections
are skipped and counted.

| Severity | Check |
| --- | --- |
| Medium | `configuration.authorizedAppIds` lists an app with no service principal in this tenant |
| Medium | `configuration.authorizedAppIds` lists an app owned by another organization (not this tenant, not Microsoft). That app can write content users then get back from Copilot. |
| Low | `state` is `limitExceeded`, so answers draw on only part of the source |
| Low | The connection has no description |

The result always includes a table of every connector users can search, so it doubles as the
inventory.

**Not covered (Graph doesn't expose it):** the staged-rollout audience and per-item access rules,
such as a gallery connector set so every user sees all content. Check those in the Microsoft 365
admin center under **Copilot > Connectors > Your connections**. Federated (live, MCP-based)
connectors aren't external connections; MP.AIGOV.1007, 1008, 1010, 1011 and 1016 cover them through
the agent catalog.

<a id="mp-aigov-1034"></a>

## MP.AIGOV.1034: AI administration roles should be eligible through PIM and held by a small number of internal users

Checks the three Microsoft Entra roles that control Copilot and agents: **AI Administrator**, **Agent ID
Administrator** and **Agent Registry Administrator**. All three are labeled privileged in the Entra roles reference.
AI Administrator can change every Copilot setting, approve and publish agents, manage admin consent request
policies, and manage the full lifecycle of agent identities and blueprints.

Reads `GET /roleManagement/directory/roleAssignmentScheduleInstances` for each role with the principal expanded.
Expanded users can omit `userType`; a nested-selection attempt failed during live validation.
The test reads `users/{id}?$select=id,userType` once per affected user, using `User.Read.All`,
and skips if user type still cannot be established. It reports:

- **Permanent active assignment** (`assignmentType` `Assigned`, no `endDateTime`). Microsoft's agent prerequisites
  guidance recommends PIM just-in-time activation for AI Administrator. (High)
- **Guest holder.** (High)
- **Service principal holder.** `MT.1209` covers agent identities with privileged roles; this catches other apps. (High)
- **More distinct holders than `MaxHoldersPerRole`** (default 3, setting `AIGOV.MaxAiAdminRoleHolders`). (Medium)

If the PIM schedule API isn't available (no Entra ID P2), the test falls back to `roleAssignments` and says it
can't tell permanent from activated assignments. AI Reader isn't checked: it can't change settings.

Framework: CISA draft SCuBA agent baseline MS.SI.6.4 (AI admin roles by least privilege); NIST 800-53 AC-6(5), AC-2(7).

> [!NOTE]
> **Validated** Nov 18, 2026 against a live test tenant. Correctly **Failed** (true positive):
> 104 active assignments across the three roles were `Assigned` with no `endDateTime`; each role
> exceeded three holders. Independent eligibility reads returned zero entries. Expanded principals
> omitted `userType`; explicit reads confirmed all 58 distinct users were members. Added explicit
> user-property reads with regression coverage; no actual guest or app assignment was present.
>
> **Seeded rerun** Nov 18, 2026: an agent identity given AI Administrator as a permanent active assignment (a test object created for this run and removed afterwards)
> was reported as a non-human holder, as expected. The guest branch is still unproven: the test tenant blocks guest invites.

<a id="mp-aigov-1035"></a>

## MP.AIGOV.1035: Agent identity blueprints should not authenticate with client secrets

Checks agent identity blueprints for client secrets. Reads `GET /applications/microsoft.graph.agentIdentityBlueprint`
with `passwordCredentials` and `keyCredentials`, then each flagged blueprint's `federatedIdentityCredentials`.

A blueprint fails when it has at least one client secret that hasn't expired, whether or not it also has a
certificate or a federated credential. Already-expired secrets are left to `MT.1208`.

This is broader than `MT.1208`, which flags a secret only when it sits beside a federated credential, is expired,
is too long-lived, or is one of too many. It is your coverage matrix row **P2**.

Framework: CISA draft SCuBA agent baseline MS.SI.2.1 (SHALL use federated credentials or certificates, not client
secrets); CISA/NSA *Careful Adoption of Agentic AI Services* (replace static, long-lived secrets); NIST 800-53 IA-5.

> [!NOTE]
> **Validated** Nov 18, 2026 against a live test tenant. Correctly **Failed** (true positive):
> 2 of 6 blueprints had an active password credential. Independent reads confirmed that
> `applications/{id}/federatedIdentityCredentials` works for this derived type; two blueprints
> returned one federated credential each. No certificate credentials were present.

<a id="mp-aigov-1036"></a>

## MP.AIGOV.1036: Enabled agent identities should have at least one active sponsor

Checks that every enabled agent identity still has an active sponsor. Reads
`GET /servicePrincipals/microsoft.graph.agentIdentity`, then each enabled agent identity's
`/microsoft.graph.agentIdentity/sponsors`. A sponsor is active when it is a group, or a user whose `accountEnabled`
isn't false.

An enabled agent identity fails when it has no sponsors left or every sponsor is disabled. Entra requires a
sponsor when an agent identity is created, so this usually means a sponsor left without a Lifecycle Workflows
sponsor transfer.

`MT.1205` covers sponsors on blueprints and blueprint principals only; `MP.AIGOV.1004` flags exactly one sponsor with
zero owners.

Framework: CISA draft SCuBA agent baseline MS.SI.3.1 (every agent SHALL have a sponsor and an owner); NIST 800-53 AC-2.

> [!NOTE]
> **Validated** Nov 18, 2026 against a live test tenant. Correctly **Passed** (true negative):
> all 11 enabled agent identities had one sponsor. Independent reads of the derived-type sponsor
> navigation returned `@odata.type` `#microsoft.graph.user` and `accountEnabled=true` for all 11.
>
> **Seeded rerun** Nov 18, 2026: an agent identity whose only sponsor was a disabled user (a test object created for this run and removed afterwards) was
> reported with "every sponsor is disabled", as expected. Both branches are now proven live.

<a id="mp-aigov-1037"></a>

## MP.AIGOV.1037: Agents discovered by Microsoft Defender should have a Microsoft Entra identity

Reconciles Microsoft Defender's agent inventory with Microsoft Entra. Runs an advanced hunting query through Graph
(`POST /security/runHuntingQuery`, via Maester's `Invoke-MtGraphSecurityQuery`) against the `AgentsInfo` table,
latest record per agent. Agents whose `LifecycleStatus` is `Deleted`, `Uninstalled` or `Blocked` are dropped, and
`Draft` agents are counted for information until they're published.

Column names differ between the `AgentsInfo` documentation (`AgentName`, `EntraAgentId`, `EntraBlueprintId`) and
some live tenants (`Name`, `EntraAgentID`, `EntraBlueprintID`). The query reads whichever exists with
`column_ifexists`. A missing `AgentsInfo` table skips with the Agent 365 prerequisite message; other query or
schema errors are reported as errors, not mistaken for a missing license.

A cloud agent fails when both `EntraAgentId` and `EntraBlueprintId` are empty: Defender sees it, but it has no Entra
identity to govern with Conditional Access, sponsors or ID Protection. Agents on the `LocalAgents` platform (tools
Defender for Endpoint found on devices) are reported for information only.

Agents on platform `Other` with no owners and no source agent ID are vendor agents from the Microsoft 365 agent
catalog (store apps). They run inside Copilot, are governed through the catalog (see `MP.AIGOV.1007`), and don't
get an Entra agent identity, so they're counted for information only. Vendor agents that act on their own, such as
Frontier agents, do have an Entra agent identity and are still checked.

Every result ends with a count by `Platform`: agents, agents with no Entra identity, and whether the platform is
counted. Some platforms run every agent as the signed-in user and never create an Entra agent identity. After you
review the counts, list those platforms in the `AIGOV.ExcludedAgentPlatforms` setting; their agents are then
reported for information only. The finding table lists at most 100 agents.

`AgentsInfo` replaced `AIAgentsInfo` in June 2026. The table needs Microsoft Defender XDR with Microsoft Agent 365;
without it the test skips. This is your coverage matrix row **G19**, now reachable through Graph.

Framework: CISA/NSA *Careful Adoption of Agentic AI Services* (trusted registry reconciled against live agents, deny
unregistered agents); NIST 800-53 CM-8; AI RMF GOVERN 1.6.

> [!NOTE]
> **Validated** Nov 18, 2026 against a live test tenant after correcting the source-column names.
> Correctly **Failed** (true positive): independent hunting returned 434 latest nondeleted agents,
> including 3 `LocalAgents`, 3 `Copilot Studio` and 428 `Other` rows. Of 431 cloud rows, 421 had
> neither Entra identifier. The corrected Maester run reports the same finding; local rows remain
> informational. The original query's scalar-column error had incorrectly triggered the table-unavailable skip.
> 428 of the flagged rows were on the `Other` platform. The platform breakdown, lifecycle and draft filters, and
> `AIGOV.ExcludedAgentPlatforms` were added afterwards so you can tell unregistered agents from a platform that
> never uses Entra identities.
>
> **Rerun** Nov 18, 2026 (commit `783b36e`): **Failed**, 421 of 429 counted agents. An independent hunting
> query agreed: 434 agents not removed, minus 3 local agents and 2 Copilot Studio drafts. All 421 were on
> platform `Other`, published to Copilot, Teams, Outlook or Office, with `ToolsAuthenticationType`,
> `Availability` and `Model` blank. The table doesn't show whether those agents run as the signed-in user, so
> no platform is excluded. `Other` is a catch-all, so excluding it would also hide real unregistered agents.
> The live schema uses `Name`, `EntraAgentID`, `EntraBlueprintID` and `Description`, not the documented names;
> `column_ifexists` handles both.
>
> **Portal check** Nov 18, 2026: the 421 were vendor agents from the Microsoft 365 agent catalog (for example
> Workday, Figma, Adobe and TeamViewer apps). Five opened in Defender's AI agents page had no owners, source agent
> ID, Entra agent ID or blueprint. A hunting query showed all 421 had no owners and no source agent ID; the 7
> `Other` agents with an Entra identity were autonomous agents such as Frontier agents and Azure SRE Agent. The
> test now counts owner-less, source-less `Other` agents as vendor catalog agents, for information. Run live with
> that rule (as a hunting query): 428 catalog agents, 3 local, 2 drafts, 1 counted Copilot Studio agent with an
> Entra identity, so the test would pass. No tenant-built Agent Builder agents were present, so it's not proven
> that those carry owners; if one has no owners, it would be treated as a catalog agent.
>
> **Maester run** Nov 18, 2026 (commit `269d53e`): **Passed** in about 10 seconds. One counted Copilot Studio agent,
> with an Entra identity; 428 `Other` agents reported as vendor catalog agents, 3 local agents and 2 drafts not
> counted. The pass comes from the classification: the 421 catalog agents still have no Entra identity.

<a id="mp-aigov-1038"></a>

## MP.AIGOV.1038: MCP tools should match the definitions you approved

Detects MCP tools that changed after you approved them (a "rug pull"). Reads every MCP tool in Copilot catalog
packages users can reach, fingerprints each tool's name, description, input schema and annotations with SHA-256, and
compares them with the baseline in the `AIGOV.McpToolBaseline` setting.

- **Changed:** a baseline tool whose fingerprint differs. (Medium)
- **New:** a reachable tool that isn't in the baseline. (Medium)
- Removed tools are listed for information only.

With no baseline set, the test skips and prints the current fingerprints as JSON. Review those tools, then add the
approved entries to `maester-config.json`:

```json
{
  "GlobalSettings": {
    "AIGOV.McpToolBaseline": [
      { "PackageId": "<package id>", "ToolName": "search", "Fingerprint": "<sha256>" }
    ]
  }
}
```

Framework: CISA/NSA *Careful Adoption of Agentic AI Services* (allow-list tools and versions, verify origin and
currency); CIS Controls v8.1 MCP Companion Guide; NIST 800-53 CM-2, CM-3.

> [!NOTE]
> **Not yet validated** against a live tenant. Unit-tested only (Pester, mocked data). Run it against your
> tenant and check the result before relying on it.
>
> Live attempt Nov 18, 2026: both reachable MCP packages exposed only `mcpServerUrl`, not tool
> definitions. The test now skips explicitly rather than printing an empty baseline as usable
> evidence. Baseline approval, changed fingerprints and repeated-run stability remain unvalidated.
>
> Seeded rerun Nov 19, 2026: the seeded app's tool definitions were readable. The test skipped (no baseline) and
> printed fingerprints for 2 tools, as designed. The drift branch still needs a run with a baseline set.

Packages that omit `mcpToolDescription.tools` are listed in the result and left out of the comparison; their
baseline entries aren't reported as removed. Tools from the other packages are still checked. Any drift fails
the test. With no drift but some packages missing definitions, the test skips as a partial check instead of
passing. If no package lists tools, it skips. It does not contact the remote MCP server to obtain missing
definitions.

Rerun Nov 18, 2026 (commit `783b36e`): still **Skipped**. Two reachable packages, zero tool definitions; an
independent read of the raw package definitions agreed. The skip reason now names those packages.

<a id="mp-aigov-1039"></a>

## MP.AIGOV.1039: MCP tool descriptions should describe the tool, not instruct the model

Checks MCP tool descriptions for text aimed at the model rather than the reader (tool poisoning), and for tools with
no behavior annotations. Reads every MCP tool in Copilot catalog packages users can reach.

- **Steering text** (Medium): the description or any text in the input schema matches a pattern such as "ignore
  previous instructions", "always call this tool", "do not tell the user", or a request to send credentials. Tune
  the patterns with the `AIGOV.McpSteeringPatterns` setting.
- **No annotations** (Low): none of `readOnlyHint`, `destructiveHint`, `idempotentHint` or `openWorldHint` is set, so
  `MP.AIGOV.1011` and reviewers can't tell what the tool does.

Matches are a prompt for review, not proof of an attack.

Framework: CISA/NSA *Careful Adoption of Agentic AI Services* (standardize tool descriptions, avoid persuasive
language, validate tool selection); NIST 800-53 SI-10.

> [!NOTE]
> **Not yet validated** against a live tenant. Unit-tested only (Pester, mocked data). Run it against your
> tenant and check the result before relying on it.
>
> Live attempt Nov 18, 2026: two reachable packages supplied no tool definitions, descriptions or
> annotations. Corrected an unsupported pass over zero parsed tools to an explicit skip.
> There were no available tool descriptions to review; steering-pattern accuracy remains unvalidated.
>
> Seeded attempt Nov 18, 2026: a custom app declaring two MCP tools was uploaded in the Teams admin center, but it
> did not appear in the Copilot package catalog within an hour, so it couldn't be evaluated. A source review found
> that a tool with both steering text and no annotations was reported for steering text only; it now lists both.
>
> **Seeded rerun** Nov 19, 2026: the custom app (a test object created for this run) reached the catalog. The test
> **Failed** (Medium) as expected: 1 tool with steering text, 0 tools without annotations. The steering branch is
> validated live; the no-annotations branch is still unit-tested only.

Packages that omit `mcpToolDescription.tools` are listed in the result; tools from the other packages are
still checked, and any steering text or missing annotation fails the test. With no findings but some packages
missing definitions, the test skips as a partial check instead of passing, because missing metadata isn't a
clean description. It does not contact remote MCP servers.

Rerun Nov 18, 2026 (commit `783b36e`): still **Skipped**. Two reachable packages, zero tool definitions; an
independent read of the raw package definitions agreed. The skip reason now names those packages.

<a id="mp-aigov-1040"></a>

## MP.AIGOV.1040: Sensitivity labels should include a sites and groups label and use unique names

Checks the sensitivity label taxonomy that Copilot DLP, Restricted Content Discovery and agent knowledge controls rely
on. Reads `GET /security/dataSecurityAndGovernance/sensitivityLabels` (v1.0) and flattens sublabels.

- **No label scoped to sites or groups** (`applicableTo` without `site` or `unifiedGroup`). (Medium)
- **Two enabled labels with the same full name** (parent/child). (Low)
- **No enabled labels at all.** (Medium)

Whether a default label is set is reported for information only: `isDefault` reflects a label policy, which this API
may not resolve at tenant level. `MT.1173` checks that labels are published.

Framework: CISA draft SCuBA agent baseline MS.SI.6.1, 6.3, 7.2, 7.4; NIST 800-53 AC-16.

> [!NOTE]
> **Validated** Nov 18, 2026 against a live test tenant. Correctly **Passed** (true negative):
> 8 root labels included 7 inline sublabels; 4 of the 15 enabled labels applied to sites or groups,
> with no duplicate full names. Root `applicableTo` values were strings; all root `isDefault`
> properties were present and false.

<a id="mp-aigov-1041"></a>

## MP.AIGOV.1041: Agent identity blueprints from other organizations should come from a verified publisher

Checks who published the agent identity blueprints that other organizations own. Reads the tenant ID and
`GET /servicePrincipals/microsoft.graph.agentIdentityBlueprintPrincipal` with `appOwnerOrganizationId` and
`verifiedPublisher`. A blueprint principal owned by another tenant (not yours, not Microsoft's) fails when
`verifiedPublisher.verifiedPublisherId` is empty.

`MT.1207` checks whether foreign blueprint principals hold privileged roles; this test checks the publisher.

> [!IMPORTANT]
> The test skips if the derived-type endpoint rejects `verifiedPublisher`, or if no returned principal
> has a populated `verifiedPublisherId`. An empty publisher object alone cannot establish that the API
> supplies this signal. Once at least one populated ID demonstrates availability, foreign principals
> with empty IDs are reported as unverified.

Framework: CISA/NSA *Careful Adoption of Agentic AI Services* (trusted registry of third-party components, verify
origin); NIST 800-53 SR-3, SA-9; AI RMF GOVERN 6.1.

> [!NOTE]
> **Not yet validated** against a live tenant. Unit-tested only (Pester, mocked data). Run it against your
> tenant and check the result before relying on it.
>
> Live attempt Nov 18, 2026: selecting `verifiedPublisher` succeeded for all 8 principals, but all
> returned empty publisher IDs. All owner-organization fields were populated; no foreign principal
> was present. The test now skips with an explicit availability reason. Foreign-publisher
> classification is not established by this tenant.

<a id="mp-aigov-1042"></a>

## MP.AIGOV.1042: Web search in Copilot should be off, or limited to Web mode

Reads the *Allow web search in Copilot* policy through `GET /copilot/admin/policySettings/microsoft.copilot.allowwebsearch`
(beta).

| Value | Meaning | Result |
| --- | --- | --- |
| `1` | Web search off for Microsoft 365 Copilot and Copilot Chat | Pass |
| `2` | Off in Work mode, on in Web mode and Copilot Chat | Pass, with a note |
| `0` or not set | On for everyone (the commercial default) | Fail (Low) |

Web search data is handled under Bing consumer terms. The API supports **delegated permissions only**, so the test
skips in an app-only run. It returns 502 when a tenant has too many group-level Copilot policies; the test skips then.

Framework: CISA draft SCuBA agent baseline MS.SI.10.3; NIST 800-53 AC-4.

> [!NOTE]
> **Validated** Nov 18, 2026 against a live test tenant for the unconfigured-policy case. Correctly
> **Failed** (true positive): raw `value=null` and `policyId=null` matched the user's confirmation
> that Apps admin center shows Not configured. The singleton request now disables paging as well
> as caching; otherwise Maester unwraps scalar `value` and loses the complete policy object.
> Configured values remain covered by unit tests, not live observations.

<a id="mp-aigov-1043"></a>

## MP.AIGOV.1043: Copilot DLP policies should block sensitive prompts, labeled content, and web search for sensitive prompts

Checks what your enforced Copilot DLP policies protect. Reads DLP policies and rules with Security & Compliance
PowerShell (`Get-MtExo -Request DlpCompliancePolicy` and `DlpComplianceRule`). Only policies that target the Microsoft 365
Copilot location, are enabled, in `Mode` `Enable` and not in simulation count, and only their rules that aren't
disabled.

| Protection | How a rule is recognized | Severity if missing |
| --- | --- | --- |
| Block prompts with sensitive info types | SIT condition + `RestrictAccess` `UploadText` or `ExcludeContentProcessing` = `Block` | Medium |
| Block labeled files and email | Sensitivity label condition + `RestrictAccess` `ExcludeContentProcessing` = `Block` | Medium |
| Block web search for sensitive prompts | `RestrictWebGrounding` = `true` | Low |
| Exclude external email from grounding (preview) | `FromScope` `NotInOrganization` + the processing block | Low |

When no enforced Copilot DLP policy exists the test skips: `MT.1175` and CIS M365 3.2.3 report that. Rule conditions
are matched from the rule's text, so confirm a *Missing* row in the Purview portal. Blocking labeled content needs
Microsoft 365 E5-level Purview; blocking prompts is available to all Copilot users.

Framework: CISA draft SCuBA agent baseline MS.SI.10.2, 10.3, 10.5, 10.6; NIST 800-53 AC-4.

> [!NOTE]
> **Not yet validated** against a live tenant. Unit-tested only (Pester, mocked data). Run it against your
> tenant and check the result before relying on it.
>
> Live attempt Nov 18, 2026 read 5 policies and 9 rules. The only Copilot policy was in
> `TestWithNotifications` with `IsSimulationPolicy=true`; the skip for no enforced policy was
> correct, not proof of rule coverage. Its `Locations` was a JSON string containing `Copilot.M365`,
> and `EnforcementPlanes` included `CopilotExperiences`. Its rule used a `RestrictAccess` array
> with `setting=UploadText`, `value=Block`, and a sensitive-information array of named conditions.
> Synthetic fixtures now use these shapes. Matching recognizes the prompt-upload action and
> requires the block value on the same action, without treating it as labeled-content grounding.
> The user confirmed the simulation state and sensitive-prompt block in Purview. Enforced-rule
> classification remains unvalidated because there was no enforced Copilot policy.
>
> **Seeded rerun** Nov 18, 2026: an enforced Copilot policy made in the Purview portal (a test object created for this run and removed afterwards) blocked
> prompts with Credit Card Number. The test failed (Medium) as expected, but reported 4 of 4 protections off: it
> missed the prompt block. Portal-made rules store `RestrictAccess` as `value=Block` with no `setting`, and put
> the activity in `AdvancedRule` as `HasActivity = UploadText`. Fixed: a block with no setting counts as a prompt
> block when the rule's activity is `UploadText`, and as a content-processing block otherwise. Unit-tested with
> the live shape; rerun to confirm it now reports 3 of 4.
>
> **Rerun** Nov 19, 2026: reported **3 of 4** protections off, as expected after the fix. Validated live.

<a id="mp-aigov-1044"></a>

## MP.AIGOV.1044: Copilot interaction audit records should be retained for at least your required period

Checks how long Copilot and agent interaction audit records are kept. Reads `Get-UnifiedAuditLogRetentionPolicy`
(Security & Compliance PowerShell). A policy covers Copilot when its `RecordTypes` include `CopilotInteraction`
(Microsoft 365 Copilot, Copilot Chat, Cowork, Security Copilot and Copilot Studio agents) and it isn't narrowed by
`Operations` or `UserIds`.

Fails (Medium) when no policy covers `CopilotInteraction`, or the longest one is shorter than `MinimumRetention`
(default `TwelveMonths`, setting `AIGOV.MinimumAiAuditRetention`). Without a policy, Audit (Standard) keeps these
records for 180 days. Coverage of `ConnectedAIAppInteraction` is reported for information.

Needs Microsoft Purview Audit (Premium); ten-year retention needs the add-on license. `MT.1172` checks that the
unified audit log is on.

Framework: CISA draft SCuBA agent baseline MS.SI.5.1, 11.4; NIST 800-53 AU-11.

> [!NOTE]
> **Validated** Nov 18, 2026 against a live test tenant for the missing-policy case. Correctly
> **Failed** (true positive): an independent `Get-UnifiedAuditLogRetentionPolicy` returned zero
> policies. With no objects, `RecordTypes`, presence of `Enabled`, and `RetentionDuration` value
> shapes could not be established; explicit-policy classification remains unvalidated.

<a id="mp-aigov-1045"></a>

## MP.AIGOV.1045: Azure OpenAI and AI Services accounts should require Entra auth, restrict network access and be covered by Defender for AI

Checks the Azure resources behind Azure OpenAI and Microsoft Foundry. Reads Azure Resource Graph for
`Microsoft.CognitiveServices/accounts` of kind `OpenAI` or `AIServices`, and each of those subscriptions' Defender for
Cloud AI plan (`Microsoft.Security/pricings/AI`). An account fails (Medium) when:

- `disableLocalAuth` isn't `true` (API keys work, with no Entra identity or Conditional Access);
- `publicNetworkAccess` is `Enabled` and `networkAcls.defaultAction` isn't `Deny`;
- the subscription's Defender for AI Services plan isn't `Standard`.

No accounts is a pass. This is the pack's only Azure check; Azure Policy may already enforce these settings.

Framework: NIST 800-53 IA-2, SC-7, SI-4.

> [!NOTE]
> **Not yet validated** against a live tenant. Unit-tested only (Pester, mocked data). Run it against your
> tenant and check the result before relying on it.
>
> Live attempt Nov 18, 2026 returned no matching AI accounts, and an independent subscription
> enumeration returned zero accessible subscriptions. The empty-inventory pass is not proof of
> account hardening or Defender coverage. No subscription was available for a pricing GET;
> `disableLocalAuth`, `publicNetworkAccess`, and `pricingTier` remain unvalidated.
>
> **Seeded rerun** Nov 18, 2026: an Azure OpenAI account created in the portal with default settings (a test object created for this run and removed afterwards)
> correctly **Failed**: public network access with default action `Allow`, and Defender for AI Services on the
> `Free` tier. Key auth was not reported, correctly: the portal created the account with `disableLocalAuth=true`.
> Resource Graph and a direct ARM read agreed. The key-auth branch is still unproven live.
>
> Rerun Nov 19, 2026 (Maester 3.0.0-rc83): same result, Failed for public network access and Defender `Free`.

<a id="mp-aigov-1046"></a>

## MP.AIGOV.1046: Azure AI model deployments should use a content filter that blocks prompt attacks

Checks the content filters on Azure OpenAI and Microsoft Foundry model deployments. Reads the accounts from
Azure Resource Graph (`Microsoft.CognitiveServices/accounts` of kind `OpenAI` or `AIServices`), then each
account's deployments (`{account}/deployments`) and content filters (`{account}/raiPolicies`) from Azure
Resource Manager. A text model deployment fails (Medium) when:

- it has no content filter (`raiPolicyName` is empty);
- its content filter doesn't turn on **and block** Prompt Shields for user prompts (the `Jailbreak` filter).
  Annotate-only still lets the attack reach the model;
- with `AIGOV.RequireIndirectAttackFilter` set to `true`, its content filter doesn't turn on and block Prompt
  Shields for indirect attacks (instructions hidden in documents, email or web pages the model reads).

Embedding, speech and image models are left out. A deployment on `Microsoft.DefaultV2` that the account
doesn't list is counted as passing, because Microsoft documents Prompt Shields for user prompts as on by
default. The filter's `Mode` is shown for information: `Asynchronous_filter` lets streamed completions
return before filtering finishes. No deployments is a pass.

Frameworks: MCSB v2 AI-2 (multi-layered content filtering); OWASP LLM01 (prompt injection) and ASI01 (agent
goal hijack); NIST 800-53 SI-10.

> [!NOTE]
> The control names
> (`Jailbreak` or "user prompt attack"; "indirect" or "document attack") are matched by pattern, and a
> control counts as blocking when `blocking` is true or `action` is `BLOCKING`.
>
> **Seeded runs** Nov 19, 2026 (a gpt-5.4-mini deployment created for these runs in the test resource group):
> with `Microsoft.DefaultV2` the test **Passed**; the account's `raiPolicies` list returned DefaultV2 with a
> `Jailbreak` filter (`enabled`, `blocking`, source `Prompt`), so the name match, not the fallback, made the pass.
> Switched to the older built-in `Microsoft.Default`, which has no Jailbreak filter, it **Failed** (Medium) with
> "Prompt Shields for user prompts off or annotate-only". Both branches are validated live. The account also lists
> `Microsoft.MAIDefault`, whose Jailbreak filter is on but not blocking. The indirect-attack filter name is still
> unconfirmed: none of the built-in filters returned it.

<a id="mp-aigov-1047"></a>

## MP.AIGOV.1047: Azure OpenAI and AI Services accounts should export their audit and request logs

Checks that Azure OpenAI and Microsoft Foundry accounts keep their resource logs. Reads the accounts from
Azure Resource Graph (`Microsoft.CognitiveServices/accounts` of kind `OpenAI` or `AIServices`), then each
account's diagnostic settings (`{account}/providers/Microsoft.Insights/diagnosticSettings`) from Azure
Resource Manager. Resource logs aren't stored anywhere until a diagnostic setting sends them to Log
Analytics, a storage account, an event hub or a partner solution.

An account fails (Medium) when no diagnostic setting with a destination turns on every category in
`AIGOV.RequiredAiLogCategories` (default `Audit` and `RequestResponse`). The `allLogs` category group counts
for every category, and the `audit` group counts for `Audit`. Settings without a destination are ignored.
No accounts is a pass.

The account supports the `Audit`, `RequestResponse`, `Trace`, `AzureOpenAIRequestUsage` and
`ManagedNetworkEvent` categories. Add `Trace` or `AzureOpenAIRequestUsage` to the setting if you need them.

Frameworks: MCSB v2 AI-6 (monitoring and detection); Five Eyes Careful Adoption of Agentic AI (logging);
NIST 800-53 AU-2, AU-12.

> [!NOTE]
> **Not yet validated** against a live tenant. Unit-tested only (Pester, mocked data). Run it against your
> tenant and check the result before relying on it.
>
> Live run Nov 19, 2026: **Passed** on the one AI account in the test tenant. A direct ARM read confirmed it: a
> diagnostic setting deployed by Azure Policy sends the `allLogs` category group to Log Analytics (its separate
> `Audit` group entry was disabled and correctly ignored). The failure branch is still unproven live.

<a id="mp-aigov-1048"></a>

## MP.AIGOV.1048: Azure AI model deployments should only use approved models

Checks that Azure OpenAI and Microsoft Foundry deployments only use models you approved. Reads the accounts
from Azure Resource Graph (`Microsoft.CognitiveServices/accounts` of kind `OpenAI` or `AIServices`), then each
account's deployments (`{account}/deployments`) from Azure Resource Manager, and compares each deployment's
model (`properties.model.name` and `version`) to `AIGOV.ApprovedModels`.

Each entry is a model name (`gpt-4.1`) or a name and version (`gpt-4o:2024-11-20`). Wildcards work
(`gpt-5*`, `text-embedding-3-*`), and matching ignores case. A deployment fails (Medium) when no entry
matches it.

The test **skips until you set** `AIGOV.ApprovedModels`, because only you know which models you approved:

```json
{
  "GlobalSettings": {
    "AIGOV.ApprovedModels": [ "gpt-4.1", "gpt-4o:2024-11-20", "text-embedding-3-*" ]
  }
}
```

Frameworks: MCSB v2 AI-1 (ensure use of approved models); OWASP ASI04 (agentic supply chain); NIST 800-53
CM-7.

> [!NOTE]
> **Not yet validated** against a live tenant. Unit-tested only (Pester, mocked data). Run it against your
> tenant and check the result before relying on it.

<a id="mp-aigov-1049"></a>

## MP.AIGOV.1049: Agents should not be able to share SharePoint content with external users

Checks that agents can't share SharePoint and OneDrive content with people outside your organization. Reads the
SharePoint tenant settings through Maester's SharePoint connection (`Get-MtSpo`, which uses `Get-PnPTenant`).

- **Pass:** `RestrictExternalSharingForAgents` is `True`, or external sharing is off for the whole tenant
  (`SharingCapability` is `Disabled`).
- **Fail (Medium):** `RestrictExternalSharingForAgents` is `False` and external sharing is on.
- **Skip:** the setting isn't returned. Microsoft lists it as preview, and older PnP.PowerShell versions don't
  read new tenant settings.

An agent that can share externally can move data out of the tenant with one action. That's the exfiltration
path the OWASP agentic list calls tool misuse.

Frameworks: OWASP ASI02 (tool misuse) and ASI03 (identity and privilege abuse); MCSB v2 AI-4 (least privilege
for agent functions); NIST 800-53 AC-21.

> [!NOTE]
> **Setting confirmed Nov 19, 2026:** `Get-PnPTenant` returned `RestrictExternalSharingForAgents = False` with
> `SharingCapability = ExternalUserAndGuestSharing` on a test tenant, so this check should fail there. The full
> **Live run** Nov 19, 2026 (Maester 3.0.0-rc83, PnP.PowerShell 3.5.0): **Failed** (Medium) as expected on the same
> tenant. Validated live. The setting is in preview.

<a id="mp-aigov-1050"></a>

## MP.AIGOV.1050: Only SharePoint admins should manage Restricted Content Discovery and Restricted Access Control

Checks that only SharePoint admins can change Restricted Content Discovery and Restricted Access Control on sites.
Reads the SharePoint tenant settings through Maester's SharePoint connection (`Get-MtSpo`, which uses
`Get-PnPTenant`).

- **Restricted Content Discovery** keeps a site's content out of organization-wide search and Microsoft 365
  Copilot answers.
- **Restricted Access Control** limits a site to the groups you name.

Both are controls you set while you fix oversharing for Copilot. When
`DelegateRestrictedContentDiscoverabilityManagement` or `DelegateRestrictedAccessControlManagement` is `True`,
site admins and owners can turn them off on their own sites. Both default to `False`. PnP.PowerShell returns
them as `DelegateRestrictedContentDiscoveryConfiguration` and `DelegateRestrictedAccessControlConfiguration`;
the check reads either name.

- **Fail (Low):** either setting is `True`.
- **Not returned:** a setting your PnP.PowerShell version doesn't read is listed and doesn't fail.
- **Skip:** neither setting is returned.

This check doesn't look at which sites have the restrictions on. Microsoft's tenant-wide report for that is
`Start-SPORestrictedContentDiscoverabilityReport` in SharePoint Online PowerShell.

Frameworks: Microsoft Zero Trust for Copilot (oversharing controls); OWASP LLM02 (sensitive information
disclosure); NIST 800-53 AC-6.

> [!NOTE]
> **Settings confirmed Nov 19, 2026:** `Get-PnPTenant` returned both settings (`...Configuration` names, both
> `False`) on a test tenant. **Live run** Nov 19, 2026 (Maester 3.0.0-rc83, PnP.PowerShell 3.5.0): **Passed** with
> both settings read under their PnP names. The pass branch is validated live; the fail branch is unit-tested only.

<a id="mp-aigov-1051"></a>

## MP.AIGOV.1051: Users should see a disclaimer before they share SharePoint content with an agent

Checks that people see a warning before they share a SharePoint site or its content with an agent. Reads the
SharePoint tenant settings through Maester's SharePoint connection (`Get-MtSpo`, which uses `Get-PnPTenant`).

- **Pass:** `EnableAgentWorkerSharingDisclaimer` is `True`.
- **Fail (Low):** it's `False`. Users can share with an agent worker or AI teammate without a prompt to think
  about what the agent will be able to read and act on.
- **Skip:** the setting isn't returned. Microsoft lists it as preview, and older PnP.PowerShell versions don't
  read new tenant settings.

Frameworks: OWASP ASI09 (human-agent trust exploitation); Microsoft Zero Trust for Copilot (oversharing);
NIST 800-53 AT-2.

> [!NOTE]
> **Setting confirmed Nov 19, 2026:** `Get-PnPTenant` returned `EnableAgentWorkerSharingDisclaimer = False` on a
> test tenant, so this check should fail there. The Maester run of this check is still pending. On Maester 3.0 RC,
> sign in with `Connect-PnPOnline` before any Maester command (see the README).

**Live run** Nov 19, 2026: **Failed** (Low) as expected, `EnableAgentWorkerSharingDisclaimer` = False. Validated live.

<a id="mp-aigov-1052"></a>

## MP.AIGOV.1052: Agents should not have active risk indicators in Microsoft Defender

Surfaces the risk indicators Microsoft Defender assigns to agents. Runs an advanced hunting query on the
`AgentsInfo` table (latest record per agent) and expands its `RiskIndicators` column. Each indicator is Defender's
own posture assessment, with a `title`, a `severity`, and `isActive`, `isExposure` and `isBlastRadius` flags.
Examples seen live: "Running on a Device with Vulnerabilities" (High), "Dormant agent" (Medium), "Published
Agent" (Low), and "Connection count" (a blast-radius indicator with no severity).

- **Fail (Medium):** an agent that isn't deleted, uninstalled or blocked has an active exposure indicator at or
  above `AIGOV.MinAgentRiskSeverity` (default `Medium`).
- **Not counted:** blast-radius indicators, indicators below the minimum (counted in a note), vendor agents
  from the Microsoft 365 agent catalog, and platforms in `AIGOV.ExcludedAgentPlatforms` (as in MP.AIGOV.1037).
- **Included:** local AI agents found on devices, since their indicators describe the device they run on.
- **Skip:** the `AgentsInfo` table isn't available.

Risk indicators need Microsoft 365 E7, or Microsoft Agent 365 (with Defender for Endpoint Plan 2 for local
agents). Without them the column is empty and the test passes.

Frameworks: OWASP ASI10 (rogue agents); MCSB v2 AI-6 (monitoring and detection); Five Eyes Careful Adoption of
Agentic AI (continuous monitoring); NIST 800-53 RA-5.

> [!NOTE]
> **Data shape confirmed Nov 19, 2026** from a live `AgentsInfo` sample: `RiskIndicators` is a property bag
> keyed by indicator ID. The query that expands it hasn't run inside Maester yet.

**Live run** Nov 19, 2026 (Maester 3.0.0-rc83): the first version errored because `title` is a KQL keyword
(`Indicator.title` must be written `Indicator['title']`). After the fix it **Failed** (Medium) as expected: 5 agents,
three local agents "Running on a Device with Vulnerabilities" (High) and two Copilot Studio agents "Dormant agent"
(Medium); one Low "Published Agent" indicator was counted in the note only. Validated live.

<a id="mp-aigov-1053"></a>

## MP.AIGOV.1053: MCP servers on agents found by Microsoft Defender should use HTTPS, trusted hosts and approval

Applies the pack's MCP rules to MCP servers that the Copilot agent catalog doesn't show. Runs an advanced hunting
query on the `AgentsInfo` table (latest record per agent) and expands its `McpServers` column. That covers MCP
servers added to Copilot Studio agents, and MCP servers configured in local agents such as GitHub Copilot CLI or
Claude Code that Microsoft Defender for Endpoint found on devices. MP.AIGOV.1008 and 1010 cover catalog packages.

An MCP server on an agent that isn't deleted, uninstalled or blocked fails (Medium) when:

- its endpoint uses plain HTTP;
- its endpoint host isn't on the allowlist (the MP.AIGOV.1010 list plus `cloud.microsoft`, which hosts
  Microsoft's Enterprise MCP server); or
- it's on a **published** agent and its `approvalModeKind` is `always_allow`, so the agent runs the server's
  tools without asking the user.

MCP servers with no endpoint, such as Copilot Studio servers reached through a Power Platform connector, are
only checked for approval. The report shows the scheme and host only, never the full URL.

Frameworks: OWASP ASI02 (tool misuse) and ASI04 (agentic supply chain); MCSB v2 AI-4 and AI-5 (least privilege
and human-in-the-loop); NIST 800-53 SC-8.

> [!NOTE]
> **Data shape confirmed Nov 19, 2026** from a live `AgentsInfo` sample: `McpServers` holds JSON strings with
> `name`, `type`, `endpoint`, and for Copilot Studio `approvalModeKind` and `authenticationUsed`. Only the value
> `always_allow` has been seen; what other values mean is unconfirmed. The query hasn't run inside Maester yet.

**Live run** Nov 19, 2026: **Passed**, 1 MCP server on an agent in use (a Copilot Studio draft with `always_allow`,
correctly not flagged because the agent isn't published). The fail branches are unit-tested only.

<a id="mp-aigov-1054"></a>

## MP.AIGOV.1054: Microsoft Entra diagnostic settings should export the agent risk logs

Checks that Microsoft Entra keeps the agent risk logs. Reads the log categories Entra offers and the tenant's
Entra diagnostic settings from Azure Resource Manager (`/providers/microsoft.aadiam/diagnosticSettingsCategories`
and `/providers/microsoft.aadiam/diagnosticSettings`).

Microsoft Entra ID Protection writes agent risk to the `RiskyAgents` and `AgentRiskEvents` categories (the
`AADRiskyAgents` and `AADAgentRiskEvents` tables in Log Analytics). Entra keeps reports for a limited time
unless a diagnostic setting sends them to Log Analytics, a storage account, an event hub or a partner solution.
Maester core's CISA MS.AAD.4.1 check covers the categories CISA names, and these two aren't among them.

- **Fail (Medium):** a category in `AIGOV.RequiredAgentLogCategories` (default `RiskyAgents`, `AgentRiskEvents`)
  that the tenant offers isn't turned on in a diagnostic setting with a destination.
- **Not offered:** a category the tenant doesn't list is shown and doesn't fail.
- **Skip:** the settings can't be read (needs an Entra role such as Security Reader or Global Reader, through
  Maester's Azure connection).

Frameworks: MCSB v2 AI-6 (monitoring and detection); Five Eyes Careful Adoption of Agentic AI (logging); NIST
800-53 AU-6.

> [!NOTE]
> **Categories confirmed Nov 19, 2026:** a test tenant's `diagnosticSettingsCategories` listed `RiskyAgents` and
> `AgentRiskEvents`. There is no separate agent sign-in category. The check hasn't run inside Maester yet.

**Live run** Nov 19, 2026: **Failed** (Medium) on the test tenant: neither `RiskyAgents` nor `AgentRiskEvents` is
exported. The fail branch is validated live.

<a id="mp-aigov-1055"></a>

## MP.AIGOV.1055: Local AI agents should ask before acting and run in a trusted process

Finds local AI agents on devices that act on their own. Runs Microsoft's documented advanced hunting query on the
`AgentsInfo` table for `Platform == "LocalAgents"` (latest record per agent) and reads
`RawAgentInfo.localAgentMetadata`:

- `autoApprove` = `"true"`: the agent runs tools and reaches resources without a person confirming each step, so
  the account and device it runs on define what it can do unsupervised.
- `trustedProcess` = `"false"`: the process hosting the agent isn't trusted.

- **Fail (Medium):** an agent that isn't deleted or uninstalled has either value.
- **Not judged:** agents that report neither value (counted in a note).
- **Pass:** no local agents, or none with either value.
- **Skip:** the `AgentsInfo` table isn't available.

Local AI agent discovery needs Microsoft Defender for Endpoint Plan 2 on onboarded Windows or macOS devices
(commercial cloud only).

Frameworks: OWASP ASI02 (tool misuse) and ASI09 (human-agent trust); MCSB v2 AI-5 (human-in-the-loop); Five Eyes
Careful Adoption of Agentic AI (human oversight); NIST 800-53 CM-7.

> [!NOTE]
> **Not yet validated** against a live tenant. Unit-tested only (Pester, mocked data). The query follows Microsoft's
> documented example; the sample from the test tenant had local agents but didn't include `RawAgentInfo`.

**Live run** Nov 19, 2026: **Passed**, 3 local AI agents, none auto-approving or in an untrusted process. The fail
branch is unit-tested only.

<a id="mp-aigov-1056"></a>

## MP.AIGOV.1056: Foundry hosted agent egress rules should be enforced and deny by default

Checks the network egress rules of Microsoft Foundry hosted agents. Reads the accounts from Azure Resource Graph
(`Microsoft.CognitiveServices/accounts` of kind `OpenAI` or `AIServices`), then each account's RAI policies
(`{account}/raiPolicies`) from Azure Resource Manager with api-version `2026-09-01`. Egress rules are stored on the
RAI policy (guardrail) a hosted agent uses, in `properties.egressPolicy`; older api-versions such as `2026-07-01`
don't return them. A policy with egress rules fails (Medium) when:

- `mode` is `Audit`: requests that should be denied are logged but still go out;
- `defaultAction` is `Allow`: any host no rule names is reachable;
- an `Allow` rule has no `match.host`, or `*`: rules are evaluated in order and the first match wins, so that rule
  lets everything through before the default action is reached.

Microsoft documents `Enforced` and `Deny` as the defaults when the values are omitted, and says a GET always returns
the effective values, so a missing value counts as the default. Policies without `egressPolicy` are counted in a note:
most RAI policies only filter model content. Accounts whose policies can't be read are named in a note; if none can
be read (no Reader role, or a region or cloud without api-version `2026-09-01`), the test skips. No accounts, or no
policy with egress rules, is a pass.

What it can't see: hosted agents are a Foundry data-plane object (`Microsoft.CognitiveServices.Data/accounts/projects/agents`),
not an Azure Resource Manager resource, so a hosted agent that uses no RAI policy with egress rules isn't found. The
result points to the Azure Policy built-in *Microsoft Foundry hosted agents should enforce resolved RAI egress
restrictions* (`d279dbb1-e60e-4ca0-8c2f-cc7a0f46166b`, preview in six regions) for that. Transform rules' static header
values are write-only and never returned, so they aren't checked.

Data source facts are from Microsoft Learn: [Add guardrails to a hosted agent](https://learn.microsoft.com/azure/foundry/agents/how-to/add-hosted-agent-guardrails#network-egress-controls),
[Govern hosted agent egress with Azure Policy](https://learn.microsoft.com/azure/foundry/agents/how-to/govern-hosted-agent-egress-azure-policy)
and the [raiPolicies 2026-09-01 reference](https://learn.microsoft.com/azure/templates/microsoft.cognitiveservices/2026-09-01/accounts/raipolicies).
Network egress controls for hosted agents became generally available on Nov 17, 2026 (Azure update 571821); Transform
rules are still in preview.

Frameworks: MCSB v2 AI-4 (least privilege for agent functions: "allowing only predefined, approved endpoints"); OWASP
ASI02 (tool misuse and exploitation); NIST 800-53 SC-7 (boundary protection).

> [!NOTE]
> **Not yet validated** against a live tenant. Unit-tested only (Pester, mocked data), and the RAI policy shape follows
> Microsoft's reference, not a live sample. Validate with a hosted agent whose guardrail has egress rules: run once in
> `Audit` (expect Fail), then `Enforced` with default `Deny` (expect Pass).
