# Coverage matrix — Maester AI-governance findings pack

Sorted Gap → Partial → Covered. Every "Existing Maester test" cites file path at
commit `616559854634e5150dbde69850c4224191635bb1` of `maester365/maester`, except the section
"Framework gap review (2026-11-18)" at the end, which was checked against commit
`512a076de7bb173045a2ebe62b0493d613ddd0b5` (Nov 17, 2026). Severity
uses Maester's real 5-value scale (`Critical/High/Medium/Low/Info`). Framework
mapping types: **Direct** = Direct requirement, **Support** = Supporting alignment,
**Org** = Organization policy, **Unmapped**.

## GAP — no existing Maester test touches this condition

| # | Surface | Candidate finding | Trigger | Data source + permission | Existing test(s) | Coverage | Severity | Framework mapping | Type | Notes |
|---|---|---|---|---|---|---|---|---|---|---|
| G1 | Agents | Catalog adoption below 5% in 90 days (tenant-wide, not per-agent) | `getMicrosoft365CopilotUsageUserDetail(period='D90')` active-user ratio < 5% of licensed seats | Graph beta, `Reports.Read.All` | none | Gap | Low | Unmapped | — | Tenant-level adoption metric; no agent-level Maester test does this aggregate math. Logic already exists in `chadmcox/Copilot` (ported concept, not code). Pilot item `MP.AIGOV.1001` additionally requires ≥1 agent in the package catalog, ≥20 reported users, and a name-matched activity column — see pilot doc. |
| G3 | Agents | Agent assigned to users directly instead of via a group | Assignment list contains individual user principals rather than group objects | Graph v1.0 `GET /copilot/admin/catalog/packages/{id}` (`allowedUsersAndGroups`/`acquireUsersAndGroups` filtered to `resourceType eq 'user'` — per-package detail call only, not the list endpoint; see pilot `MP.AIGOV.1003`) | none | Gap | Low | Org | — | No Maester test inspects assignment-target type (user vs. group) for any object in this area. |
| G4 | Agents | Unclear name/description (empty or placeholder display name/description) | `displayName`/`description` empty, whitespace, or matches a placeholder regex (`test`, `demo`, `tbd`) | Graph v1.0 | none | Gap | Info | Org | — | Pure hygiene finding; no equivalent exists. |
| G5 | Blueprints / Blueprint Principals | Single sponsor (exactly one, where policy expects redundancy) and no owner as backup | Sponsor count == 1 on `.../sponsors` AND zero active owners | Graph v1.0 `agentIdentityBlueprints/{id}/sponsors`, `.../blueprintPrincipals/{id}/sponsors` | MT.1205 — "Agent Identity Blueprints and Blueprint Principals should have assigned sponsors" (full source read: queries the same `/sponsors` sub-resource on both object types, fails only when sponsor count == 0 or every sponsor is disabled) | Gap (adjacent to a Covered test — see note) | Low | Org | — | MT.1205 only fires at **zero** sponsors (or all-disabled). A tenant with exactly one enabled sponsor and no owner passes MT.1205 today; this single-point-of-failure condition is the real Gap. Scope corrected from "Agent identities" (generic) to Blueprints/Blueprint Principals specifically — MT.1205 does not cover plain Agent Identities or Agent Users, and no evidence those object types expose a `/sponsors` relationship at all (unconfirmed, flagged for Phase 2). Pilot item `MP.AIGOV.1004` has since confirmed agent identities **do** expose `$expand=sponsors` and extends this rule to all three object types — see pilot doc. |
| G2a | Agents | Agent available/assigned to everyone — merged finding, covering both the Copilot-Studio-environment "Everyone" assignment **and** `availableTo=allowedForAll`/`deployedTo=acquiredForAll` for a custom/external (non-Microsoft-published) package | Either: Copilot Studio agent assignment scope = Everyone/tenant default rather than a named group; **or** `copilotPackage.availableTo == allowedForAll` OR `.deployedTo == acquiredForAll` AND `publisher` is not on the Microsoft-published allowlist (see pilot doc `MP.AIGOV.1007`) | Copilot Studio admin surface (Dataverse) for the assignment-scope condition; Graph v1.0 `GET /copilot/admin/catalog/packages`, `CopilotPackages.Read.All` (license-gated) for the package-catalog condition; confirmed `copilotPackage.availableTo` (`packageAllowStatus`) and `.deployedTo` (`packageAcquireStatus`) are real, documented, GA (v1.0) properties | MT.1113 (broad **sharing/access-control policy** — adjacent, not the same property) | Gap | High | nist-800-53-r5:AC-6 | Support | **Merged this revision** — the original G2 (Copilot-Studio "Everyone" assignment) and G2a (package-catalog allow/deploy status) are the same underlying governance question (is this agent available to everyone, tenant-wide) reached through two different data sources; tracked as one finding with two possible evidence sources rather than two separate rows. Severity raised to High (was Medium on the old G2) to match the package-catalog condition's severity, since either source alone is sufficient to trigger it. |
| G7 | Agents without Agent ID | Classic Copilot Studio service principal not registered in Agent ID (phrased as a state) | Service principal has one of the Copilot Studio tags (`AgentCreatedBy:CopilotStudio`, `AgenticApp`, `AIAgentBuilder`, `AgenticInstance`, `power-virtual-agents-*`) but has no matching `agentIdentityBlueprintId`/`agentIdentity` object | Graph v1.0, filter `servicePrincipals` by the Copilot Studio tag set (same tags used by pilot item `MP.AIGOV.1005`), cross-reference against `servicePrincipals/microsoft.graph.agentIdentity` | none (MT.1200 checks the reverse direction: agent identity → blueprint, not classic bot → agent identity) | Gap | Info | Org | — | Trigger corrected to match the pilot's actual data source (service-principal tags), not a "Copilot Studio bot list," which was never a confirmed Graph-queryable object in this research. Confirmed no existing test walks from the classic/legacy object to Agent ID; MT.1200/1201/1203 all start from the *new* Agent ID objects. |
| G8 | Connectors | Agent using non-Microsoft/custom connector with no DLP policy covering it | Power Platform connector list for an environment includes a non-Microsoft connector id not present in any `ruleSet`/DLP policy's connector groups | Power Platform API `connectivity/environments/{id}/connectors`, `Get-AdminDlpPolicy` or `governance/ruleBasedPolicies` | none | Gap | Medium | Unmapped | — | **Corrected**: MT.1118 is not an "unapproved connector" test (see C6 fix) — it checks the *authentication mode* a connection uses, not whether the connector itself is on a DLP-approved list. There is still no Maester test that cross-references connectors against DLP policy coverage; this remains a clean Gap, not Partial. |
| G10 | Connectors | Connector allowed in Business group that should be Blocked (tenant allow/deny-list drift) | Business-classified group in a DLP policy contains a connector the tenant baseline considers Blocked-tier | Power Platform API/DLP policy | none | Gap | Medium | Org | — | Requires an org-defined baseline list; not a generic Maester-testable condition without tenant input. |
| G11 | Connectors | Environment with no DLP policy at all | Environment ID absent from every DLP policy's environment scope | Power Platform API | MT.1181 is a **Conditional Access** test for agent risk sign-in blocking, not DLP — unrelated surface, not a true adjacent test | Gap | Medium | cisa-scuba (verify — SCuBA's Power Platform baseline doc was not re-checked this run for a DLP-specific MS.POWERPLATFORM.* ID) | Unmapped (pending verify) | — |
| G12 | Topic hygiene (not Skills — see note) | Topic unreviewed (no recorded review/approval metadata) | Topic object has no owner-review timestamp/field | Same Copilot Studio Topic surface MT.1121 reads (Dataverse via `Get-MtAIAgentInfo`, not pure Graph) | none | Gap | Low | Org | — | **Relabeled.** "Skills" and Copilot Studio "Topics" are not the same object — Microsoft Learn's Skills model (Generative/Markdown `SKILL.md` packages vs. deterministic Topics) is a separate, newer Cowork-plugin concept. G12–G14 were originally filed as "Skills" findings but actually describe Topic-level hygiene; renamed accordingly. The real Skills/Tools(MCP) surface is addressed separately below (see "Skills and MCP — surface redefinition"). |
| G13 | Topic hygiene (not Skills — see note) | Topic broad scope (no custom-instruction/scope boundary at the individual Topic level) | Topic-level instruction/scope breadth | Same surface as MT.1121 (Dataverse) | MT.1121 (agent-level custom instructions) | Partial | Medium | Unmapped | — | MT.1121 checks the **agent's** overall custom instructions exist; it does not check an individual **Topic's** own scope/breadth. |
| G14 | Topic hygiene (not Skills — see note) | Stale Topic (not modified in N days — same concept as MT.1117 but at Topic grain, not published-agent grain) | Topic `LastModifiedTime` beyond threshold | Same surface as MT.1117 (Dataverse) | MT.1117 (agent-level dormancy) | Partial | Low | Org | — | Same object-granularity gap as G13: agent-level vs. topic-level. |
| G14a | Blueprints | Client credential nearing expiration (a future warning window, before actual expiry) | Secret `endDateTime` within N days of now but not yet past | Graph v1.0 `agentIdentityBlueprints/{id}` passwordCredentials | MT.1208 (full source read: flags **already-expired** secrets, secrets valid >730 days, >2 active secrets, and a secret kept alongside a federated identity credential — it has no forward-looking "expiring within N days" warning condition) | Gap | Low | nist-800-53-r5:IA-5 (Supporting — MT.1208 itself uses this control ID for the related expired-credential condition) | Support | **Built and live-validated as `MP.AIGOV.1009`** (configurable `WarningDays`, default 30; explicitly excludes already-expired secrets, which stay MT.1208's job). Granular split of the original "credentials expiring or expired" candidate after the full MT.1208 read: "expired" is Covered (see C-table), "nearing expiration" is not. |
| G15 | Billing | Spending policy with no ceiling (no credit cap / unlimited) | `spendingPolicies/{id}` has no `limit`/cap property set, or cap is null/unbounded | Graph beta `/copilot/costManagement/spendingPolicies` | none | Gap | Medium | Unmapped | — | **Built and live-validated as `MP.AIGOV.1013`.** Schema confirmed via the beta `$metadata`: `periodLimit` is an `@odata.type`-discriminated `costManagementQuantity`, either `limitedCostManagementQuantity` (numeric cap) or `unlimitedCostManagementQuantity` (no cap). Live run: all 8 currently-enabled policies in the test tenant were unlimited — true positive. |
| G16 | Billing | Policy group with fewer than 2 owners, or no description | Group backing a spending-policy audience has <2 owners / empty description | Graph v1.0 (group object) + beta cost-management link | none | Gap | Low | Org | — | **Built and live-validated as `MP.AIGOV.1014`.** Reads `assignedGroups` via the confirmed type-cast path (`.../{id}/microsoft.graph.selectedGroupsSpendingPolicy/assignedGroups`), then each group's owners/`description`. Live run: all 8 distinct backing groups had zero owners, several also had no description — true positive. |
| G17 | Billing | Members assigned directly to a spending policy (not via group) | `assignedGroups` audience list bypassed by direct member assignment, if the API allows it | Graph beta `/copilot/costManagement/spendingPolicies/{id}/.../assignedGroups` | none | Dropped — not a real condition | — | — | — | **Confirmed not buildable.** A full read of the beta `$metadata` for the `spendingPolicy` hierarchy found exactly two concrete subtypes: `allUsersSpendingPolicy` (no group-assignment property at all) and `selectedGroupsSpendingPolicy` (only a group-collection `assignedGroups`). No individual-user-direct-assignment subtype exists anywhere in the schema, so a policy cannot bypass group assignment this way — same disposition as the dropped G21. |
| G18 | Billing | Overlapping/contradictory spending policies (two policies both scope the same group/service with conflicting caps) | Cross-policy audience-overlap detection | Graph beta, same endpoint | none | Gap | Medium | Org | — | **Built as `MP.AIGOV.1015`; revised 2026-11-06** to apply Microsoft's documented rule that the most permissive overlapping policy is enforced (higher limit wins, limits not combined). Now includes all-users policies, reports the effective per-user limit and which lower caps are overridden (High if overridden by Unlimited, Medium if by a higher cap, Low for redundant or incomparable overlaps). Resource-scoped policies aren't in Graph yet, so resource-vs-identity precedence is a manual check. Re-validation against a live tenant pending. |
| G19 | Agents | Cloud agent discovered by Defender but absent from the Agent 365 registry | Defender XDR Advanced Hunting/App Governance surfaces an agent/app identity with no matching `microsoft.graph.agentIdentity` object | Defender Advanced Hunting (KQL) + Graph v1.0 `servicePrincipals/microsoft.graph.agentIdentity` cross-reference | none | Gap | Medium | Unmapped | — | **Built as `MP.AIGOV.1037` (2026-11-18)** through Graph `POST /security/runHuntingQuery` on the `AgentsInfo` table (which replaced `AIAgentsInfo` in June 2026), so it no longer needs a separate Defender connection; it still needs Defender XDR with Agent 365. Original note: Defender-dependent, explicitly outside the Graph-only pilot. Distinct from G7: G7 is the classic-Copilot-Studio-SP-tag-based state ("not registered in Agent ID"); this is Defender's independent discovery signal catching agents/apps outside both the classic-SP-tag detection and the Agent ID registry entirely. Needs MDA App Governance/MDI, same dependency class as MT.1077-1079. |
| G20 | Tools/MCP | MCP server endpoint reachable over plain `http://` instead of `https://` | Discovered MCP server URL scheme is `http` | Graph v1.0 `copilot/admin/catalog/packages` + per-package `elementDetails[].elements[].definition` JSON (`toolSource.remoteMcpServer.mcpServerUrl`), `CopilotPackages.Read.All` — **corrected this revision: confirmed live as Graph-only, not Defender-dependent** | none — MT.1120 is a different check (reviews whether MCP **tools** have been reviewed/approved, via Dataverse agent-tool metadata; it does not inspect the MCP server's URL scheme) | Gap | High | Unmapped | — | **Built and live-validated as `MP.AIGOV.1008`.** Not the same finding as C8/MT.1120 — MT.1120 is tool-review hygiene, not transport-security inspection of the MCP endpoint itself. Live run against the test tenant: 37/37 MCP packages were `https://`, zero findings (true negative). |
| G22 | Agents | Blocked package with an open pending request | Package status = Blocked AND a pending install/consent request exists | Graph v1.0 `copilot/admin/catalog/packages` (`isBlocked` + `requestStatus`/`requestType` filters; confirmed both properties exist, license-gated) | none — MT.1118 does not apply here (it is the maker-auth connection check, not a package-request-status check) | Gap | Low | Org | — | **Reclassified from Partial.** No Maester test reads package *request* status at all; this is the `chadmcox/Copilot` "blocked + pending" finding, confirmed as a real, distinct Graph v1.0 object (the Package Management API's `requestStatus`/`requestType` filters, GA since the referenced "August 2026" what's-new entry). This is pilot item `MP.AIGOV.1002`. |
| G21b | Tools/MCP | MCP server hosted on a domain outside a configurable allowlist | Discovered `mcpServerUrl` host does not match any entry in `-AllowedHosts` (default Microsoft domain suffixes only) | Graph v1.0 `copilot/admin/catalog/packages` + per-package `elementDetails` (same `mcpServerUrl` field as G20) | none | Gap | Medium | nist-800-53-r5:SA-9 | Support | **Built and live-validated as `MP.AIGOV.1010`.** Distinct design from the dropped G21: rather than a static, non-tunable "non-Microsoft host" signal that would flag all 37 MCP packages in this tenant with zero differentiation, `.1010` takes a configurable allowlist so an admin curates it as vendors are reviewed — after which only genuinely new/unreviewed hosts surface. Live run: 37/37 packages flagged non-allowlisted under the (intentionally empty-of-vendors) default allowlist — expected true positive, not a design flaw. |
| G23 | Tools/MCP | MCP tool with a destructive or open-world effect inside a tenant-wide package | Package `elementTypes` contains `MCPServers`/`AgentConnectors`, package is tenant-wide (`availableTo=allowedForAll` or `deployedTo=acquiredForAll`, same signal as G2a/`.1007`), AND any tool's `annotations.destructiveHint` or `.openWorldHint` is `true` | Graph v1.0 `copilot/admin/catalog/packages` + per-package `elementDetails[].elements[].definition` (`toolSource.remoteMcpServer.mcpToolDescription.tools[].annotations`) | none | Gap | High | nist-800-53-r5:AC-6 | Support | **Built and live-validated as `MP.AIGOV.1011`.** Live run found `openWorldHint: true` tools in "Moody's Credit MCP", a tenant-wide package — true positive. Combines the tenant-wide signal (`.1007`/G2a) with the tool-annotation schema confirmed live this round. |
| G24 | Skills | Agent skill has a weak/empty frontmatter description, or is exposed to Copilot inside a tenant-wide package | Package `elementTypes` contains `AgentSkills`; per-skill `frontmatter.description` length < a configurable `-MinDescriptionLength` (default 40), OR `expose_skill_to_copilot=true` AND the package is tenant-wide (same signal as G2a/G23) | Graph v1.0 `copilot/admin/catalog/packages` + per-package `elementDetails[].elements[].definition` (`expose_skill_to_copilot`, `frontmatter.{name,description}`) | none | Gap | Medium | nist-800-53-r5:CM-7 | Support | **Built and live-validated as `MP.AIGOV.1012`.** First finding built against the `AgentSkills`/`SKILL.md` surface described in "Skills and MCP" below. Live run: 32 packages carry an agent-skill element; confirmed true positive against real data. |
| G25 | Tools/MCP | MCP server uses weak or no authentication | Per-package detail `toolSource.remoteMcpServer.authorization.type` (same JSON path as G20/G21b/G23) is `None`/missing (High), or `ApiKeyPluginVault`/`AzureKeyVault`/`ConnectionVault` (Medium, a static secret rather than an identity flow); `OAuthPluginVault`/`DynamicClientRegistration` pass | Graph v1.0 `copilot/admin/catalog/packages` + per-package `elementDetails`, `CopilotPackages.Read.All` | none | Gap | High | nist-800-53-r5:IA-2 | Support | **Built as `MP.AIGOV.1016`** (PR A). Confirmed documented `authorization.type` enum values via the remote-MCP-server configuration guide and the `root.agentConnectors.toolSource.remoteMcpServer.authorization` schema reference; worse when the package is tenant-wide, same signal as G2a/G23. Revised after the 2026-11-10 live run: a missing `authorization` block is Medium on a custom package and not reported on a Microsoft first-party one (the Dynamics 365 Sales/Service connectors on `agent365.svc.cloud.microsoft` carry none); explicit `None` stays High. |
| G26 | Conditional Access | No enabled Conditional Access policy targets agent identities at all, or agent-targeting policies exist but are all report-only/disabled | `conditions.clientApplications.includeAgentIdServicePrincipals` non-empty, `.agentIdServicePrincipalFilter` set, or `conditions.agentIdRiskLevels` non-empty, on an enabled policy | Graph beta `identity/conditionalAccessPolicies`, `Policy.Read.All` | MT.1181 only checks the narrow case of `agentIdRiskLevels` containing `high` **and** a block grant control on an enabled policy — confirmed by reading its source; this finding is broader and does not duplicate it | Gap | High | nist-800-53-r5:AC-2(12) | Support | **Built as `MP.AIGOV.1017`** (PR A). The agent-identity-targeting `clientApplications` properties (`includeAgentIdServicePrincipals`, `agentIdServicePrincipalFilter`) and `conditionalAccessConditionSet.agentIdRiskLevels` exist only on the beta schema, confirmed by comparing beta and v1.0 resource reference pages side by side. |
| G27 | Agent identities | Agent identity currently at risk (Identity Protection), not yet remediated or dismissed | `riskState eq 'atRisk'` on `identityProtection/riskyAgents` | Graph beta `identityProtection/riskyAgents`, `IdentityRiskyAgent.Read.All` | none | Gap | High | nist-800-53-r5:IR-4 | Support | **Built as `MP.AIGOV.1018`** (PR A). Confirmed the documented endpoint and exact least-privileged permission name (`IdentityRiskyAgent.Read.All`, distinct from the pre-existing `IdentityRiskyServicePrincipal.Read.All`) via the Graph permissions reference. `confirmedCompromised` agents are reported alongside but don't drive the Fail outcome, since that's an already-concluded worse state, not an unremediated pending one. |
| G28 | Agent identities | Agent identity has user-consented (non-admin) delegated Graph permissions, especially a scope on Maester's own MT.1223 high-risk list | `GET /oauth2PermissionGrants?$filter=clientId eq '{agent identity object ID}' and consentType eq 'Principal'`, grouped per agent by consenting-user count and scope set | Graph v1.0 `oauth2PermissionGrants`, `Directory.Read.All` | MT.1223 checks **application** permission grants on agent identities; this finding is the **delegated**, user-consented side of the same risk surface — confirmed distinct by reading MT.1223's source | Gap | Medium (High if a granted scope is on MT.1223's list) | nist-800-53-r5:AC-6 | Support | **Built as `MP.AIGOV.1019`** (PR A). MT.1223's high-risk scope list was read directly from its source (`Get-MtEntraAgentHighRiskGraphPermissionFinding.ps1`, pinned commit `616559854634e5150dbde69850c4224191635bb1`) rather than re-derived from memory, since that hashtable isn't exported from the module. |
| G29 | Billing | Resource-scoped spending policy problems — scope covers All environments, no per-agent limit, an agent covered by more than one enabled resource policy, or an identity policy with auto-apply-new-services on | Would read a resource/environment/agent-scoped `spendingPolicy` derived type and its per-agent-limit/auto-apply properties | Graph beta `/copilot/costManagement/spendingPolicies` | none | Dropped — not buildable today (schema not exposed) | — | — | — | **Confirmed not buildable (2026-11-06).** The Microsoft 365 admin center's Cost management dashboard supports resource-based spending policies (scope **Resources** → "Specific resource" or "Resource collection"/environments, with precedence over identity-based policies and an "Auto-apply new services" toggle — see [Usage-based billing and cost management for Copilot Credits](https://learn.microsoft.com/copilot/implement/usage-based-billing-manage-copilot-studio-costs) and [Manage the cost of AI experiences](https://learn.microsoft.com/en-us/copilot/plan/usage-based-billing-overview-copilot-credits)), but the Graph beta `spendingPolicy` abstract type documents **only two** derived types — `allUsersSpendingPolicy` and `selectedGroupsSpendingPolicy` — confirmed both via the official API reference and a live query (all 11 policies in the test tenant are `selectedGroupsSpendingPolicy`; raw JSON has no undocumented fields). No per-agent-limit, environment, or auto-apply-new-services property exists anywhere in `spendingPolicy`, its two derived types, or `spendingPolicyServiceSetting`. `MP.AIGOV.1013` would already evaluate a resource-scoped policy if one existed in this endpoint's response, since it reads the flat list with no `@odata.type` filter and only touches inherited base properties (`status`, `periodLimit`) — this is moot until Microsoft exposes the type. Revisit once a resource/environment/agent-scoped `spendingPolicy` subtype is documented or observed live; see the README's Manual checks section for the interim admin-center-only verification steps. |
| G30 | Billing | Spending policy covers all users, isn't enabled, has no group, links a deleted group, has no billing method, or a per-user cap below 2,000 | Policy type/status/billingMethods/perUserLimit; assignedGroups; GET groups/{id} 404 | Graph beta copilot/costManagement + v1.0 groups | none | Gap | High | Org | — | **Built as `MP.AIGOV.1025`** (ported from chadmcox/Copilot Billing Health Check policy rules). Not yet validated live. |
| G31 | Billing | Enabled spending policy has no email alert, a disabled/deleted alert recipient, or only one recipient | emailThresholdSettings.isEnabled; emailThresholdSettings/recipients; GET users/{id} | Graph beta copilot/costManagement + v1.0 users | none | Gap | Medium | Org | — | **Built as `MP.AIGOV.1026`**. Not yet validated live. |
| G32 | Billing | Group behind a spending policy is a Microsoft 365/non-security group, has nested groups, is empty, or is dynamic (Info) | groupTypes, securityEnabled; members/microsoft.graph.group; members $top=1 | Graph v1.0 groups | none | Gap | Medium | Org | — | **Built as `MP.AIGOV.1027`**. Not yet validated live. |
| G33 | Billing | Spending-policy group member is disabled, a guest, inactive for 90 days, or lacks a working Copilot license when the policy turns on cowork/code | transitiveMembers/microsoft.graph.user; signInActivity (batched); subscribedSkus | Graph v1.0 groups/users/subscribedSkus + beta serviceSettings | none | Gap | Medium | Org | — | **Built as `MP.AIGOV.1032`**. Sign-in check needs AuditLog.Read.All + Entra ID P1 and is skipped (not failed) without them. Not yet validated live. |
| G34 | Agents | Custom/external agent or tool unused: not blocked, no activeUsers, lastUsedDateTime empty or older than StaleDays, not modified in StaleDays | Per-package detail activeUsers, lastUsedDateTime, lastModifiedDateTime | Graph v1.0 copilot/admin/catalog/packages/{id} | MT.1117 (Copilot Studio agents only, via Dataverse) | Gap | Medium | Org | — | **Built as `MP.AIGOV.1020`**. Default StaleDays 180 (Maester norm), 90 documented. Not yet validated live. |
| G35 | Agents | Group an agent or tool is assigned to no longer exists, has fewer than 2 owners, or has no description | Per-package allowedUsersAndGroups/acquireUsersAndGroups (resourceType group) → GET groups/{id}, /owners | Graph v1.0 | none | Gap | Medium | Org | — | **Built as `MP.AIGOV.1021`**. Not yet validated live. |
| G36 | Agent identities | Agent identity or blueprint principal holds a broad Graph permission outside MT.1223’s list (high-privilege list = High; other *.ReadWrite.All = Medium) | appRoleAssignments (+ inherited for agent identities), admin-consented oauth2PermissionGrants on Microsoft Graph | Graph v1.0 + beta inherited* | MT.1223 (12 escalation permissions only) | Partial | High | Support | — | **Built as `MP.AIGOV.1022`**. Excludes MT.1223’s list (unit test keeps it identical to .1019’s copy). Not yet validated live. |
| G37 | Agent identities | Unclear name on agent identities and blueprints; poor description on blueprints | displayName / description pattern rules (chadmcox/Copilot list) | Graph v1.0 | none (MP.AIGOV.1006 covers packages) | Gap | Medium | Org | — | **Built as `MP.AIGOV.1023`**. Not yet validated live. |
| G38 | Agents without Agent ID | Classic Copilot Studio service principal with no owner (Medium), or enabled with no sign-in in StaleDays (Low) | Tag search (same as .1005) → owners; reports/servicePrincipalSignInActivities | Graph v1.0 + beta reports | none | Gap | Medium | Org | — | **Built as `MP.AIGOV.1024`**. Sign-in check skipped (not failed) without AuditLog.Read.All. Not yet validated live. |
| G39 | Connectors | Synced Copilot connector users can search takes content from an app with no service principal here or one owned by another organization (Medium); index limit exceeded or no description (Low) | `state` in ready/limitExceeded; `configuration.authorizedAppIds` → servicePrincipals `appOwnerOrganizationId` vs. tenant and Microsoft tenant IDs | Graph v1.0 `external/connections`, `ExternalConnection.Read.All` + `Application.Read.All` | none | Gap | Medium | nist-800-53-r5:SI-7 | Support | **Built as `MP.AIGOV.1033`**. Staged-rollout audience and per-item access rules aren't in Graph, so they stay a manual check. Not yet validated live. |
| G40 | Connectors | Connector findings counted packages users can't reach | `isBlocked = true` or `availableTo = allowedForNone` | Graph v1.0 `copilot/admin/catalog/packages` | — | Fix | — | — | — | **Scope fix** across `.1007`, `.1008`, `.1010`, `.1011`, `.1016` via `Test-AIGovPackageUserAccessible`: blocked and allowed-for-no-one packages are skipped and counted. Missing values count as reachable. |
| G41 | Agents | Package kind and vendor scope fixes | `elementTypes` DeclarativeCopilots / AgentMetadatas; `type` thirdParty or external; `availableTo` allowedForNone | Graph v1.0 `copilot/admin/catalog/packages` | — | Fix | — | — | — | **2026-11-11 live catalog run.** `Get-AIGovPackageKind` and `.1007` now treat DeclarativeCopilots, AgentMetadatas (Copilot Studio agents shared in the tenant), SuperAppAgent and AgenticUserTemplates as agents. In that tenant, 179 of 412 packages, including three tenant-built agents available to all users, had been skipped as Apps. `.1006` now checks only tenant-built packages (`Test-AIGovTenantPackage`). `.1020` now checks only packages people can reach (`Test-AIGovPackageUserAccessible`). |

## PARTIAL — an existing test touches the surface but not the exact condition

| # | Surface | Candidate finding | Trigger | Data source + permission | Existing test(s) | Coverage | Severity | Framework mapping | Type | What's missing |
|---|---|---|---|---|---|---|---|---|---|---|
| P2 | Blueprints | Client secret retained where a certificate (or FIC) would remove the live fallback (as a standalone preference, not only when paired with a FIC) | Blueprint has any `passwordCredentials` entry, independent of whether a FIC also exists | Graph v1.0 `agentIdentityBlueprints/{id}` | MT.1208 (full source read: only flags secret-retention when a FIC is **also** present on the same blueprint — "a live fallback that defeats the point of migrating to FIC") | Partial | Low | Org | — | A blueprint with only a plain client secret and **no** FIC passes MT.1208 entirely; the "prefer certificate/FIC over secret" baseline is not enforced as a standalone condition, only the secret+FIC combination. **Built as `MP.AIGOV.1035` (2026-11-18)**: CISA's draft SCuBA agent baseline MS.SI.2.1 makes this a SHALL. |
| P3 | Billing | — (no Partial billing items; all billing candidates are clean Gaps since no Maester test touches `/copilot/costManagement` at all) | | | | | | | | |

**Reclassified this revision:** the former P1 ("Blocked package with an open
pending request") moves to the Gap table as **G22** — per review feedback, there is
no adjacent Maester test at all for package request-status (the entry previously
listed "none" under Existing test(s), which is a Gap signature, not Partial).

**Rows removed this revision (G6, P2–P5 as originally numbered):** the prior draft
left "moved to Covered" stub rows in this table after re-reading source and finding
they were fully covered. Per review feedback those stubs are deleted outright rather
than cross-referenced — see the Covered table below for MT.1204 (owners), MT.1206
(inactivity, includes never-signed-in), MT.1207 (foreign/multi-tenant privileged
role), MT.1223 (high-risk Graph permissions), and MT.1209/MT.1210 (privileged
directory roles). The stray MT.1181 cross-reference under the old G11 note has also
been removed — MT.1181 is Conditional Access, not DLP, and is not an adjacent test
for that finding.

**G21 dropped, then rebuilt as G21b with a different design:** the original static
"non-Microsoft host" signal was investigated against the live test tenant and found
fundamentally flawed — 37/37 MCP connectors in the catalog are hosted on
non-Microsoft SaaS domains (Tavily, Asana, Xero, FactSet, etc.). That is inherent to
using third-party MCP tooling, not an anomaly, so a static version produces zero
differentiating signal and fully overlaps with `.1007`'s existing custom/external
classification. **G21b** replaces it with a configurable allowlist (`-AllowedHosts`,
default Microsoft-only) so an admin curates approved vendors over time, after which
only genuinely new/unreviewed hosts surface — built and live-validated as
`MP.AIGOV.1010`.

## COVERED — an existing Maester test already implements this exact finding

| # | Surface | Candidate finding | Existing test | File | Severity | Control (as shipped) |
|---|---|---|---|---|---|---|
| C1 | Agents | Broad sharing/access-control policy on an agent | MT.1113 | `tests/maester/copilot-studio/Test.MT.1113.ps1` | High | `nist-800-53-r5:AC-3` |
| C2 | Agents | Agent allows unauthenticated use | MT.1114 | `tests/maester/copilot-studio/Test.MT.1114.ps1` | High | `nist-800-53-r5:IA-2` |
| C3 | Agents | Risky HTTP configuration (non-443 port / HTTP action) | MT.1115 | `tests/maester/copilot-studio/Test.MT.1115.ps1` | Medium | `nist-800-53-r5:SC-7` |
| C4 | Agents | Agent sends email with AI-controlled inputs | MT.1116 | `tests/maester/copilot-studio/Test.MT.1116.ps1` | High | `nist-800-53-r5:AC-4` |
| C5 | Agents | Published agent dormant (no modification in 180 days) | MT.1117 | `tests/maester/copilot-studio/Test.MT.1117.ps1` — reads Copilot Studio via `Get-MtAIAgentInfo`, **Dataverse-backed, not pure Graph** | Low | none shipped |
| C6 | Connectors | Connection uses maker (author) authentication instead of invoker/end-user authentication | MT.1118 — "AI agents should not use author (maker) authentication for connections" (real title, corrected; full source read: parses each tool's YAML `Data` for a `connectionReference:`, flags it unless the YAML also sets `mode: Invoker`) | `tests/maester/copilot-studio/Test.MT.1118.ps1` — same Dataverse surface as MT.1117/1121 | Declared `Medium`, **but the runtime finding call emits `-Severity "High"` — a mismatch between the declared attribute and the shipped result, worth citing precisely** | none shipped |
| C7 | Agents | Hard-coded credentials in topic logic | MT.1119 | `tests/maester/copilot-studio/Test.MT.1119.ps1` | High | `nist-800-53-r5:IA-5(7)` |
| C8 | Agents | MCP server tools used without review | MT.1120 | `tests/maester/copilot-studio/Test.MT.1120.ps1` | Medium | none shipped |
| C9 | Agents | Generative orchestration enabled with no custom instructions | MT.1121 | `tests/maester/copilot-studio/Test.MT.1121.ps1` — Dataverse-backed via `Get-MtAIAgentInfo`, same as MT.1117/1118 | Medium | none shipped |
| C10 | Agents | Orphaned ownership (no owner, or every owner disabled) | MT.1122 | `tests/maester/copilot-studio/Test.MT.1122.ps1` | Medium | none shipped |
| C11 | Agent identities | No agent identity ↔ blueprint principal match (orphaned) | MT.1200 | `tests/maester/entra/Test.MT.1200.ps1` | Medium | none shipped |
| C12 | Agent identities | Agent user with no parent agent identity | MT.1201 | `tests/maester/entra/Test.MT.1201.ps1` | Medium | none shipped |
| C13 | Agent identities | Blueprint principal with no matching blueprint | MT.1203 | `tests/maester/entra/Test.MT.1203.ps1` | Medium | none shipped |
| C14 | Agent identities | No sponsor/owner on any Agent ID object | MT.1204 | `tests/maester/entra/Test.MT.1204.ps1` | Medium | `nist-800-53-r5:AC-2` |
| C15 | Agent identities | Sponsor assigned but disabled/deleted (zero *active* owners) | MT.1204 | same file — checks `accountEnabled` on owners, not merely presence | Medium | `nist-800-53-r5:AC-2` |
| C16 | Blueprints / Blueprint Principals | Zero sponsors, or every sponsor disabled — scoped strictly to these two object types, via `.../sponsors` (not `.../owners`) | MT.1205 — "Agent Identity Blueprints and Blueprint Principals should have assigned sponsors" (full source read) | `tests/maester/entra/Test.MT.1205.ps1` | Medium | `nist-800-53-r5:AC-2` |
| C17a | Blueprints | Client credential already expired (`passwordCredentials[].endDateTime` in the past) | MT.1208 — "should not have expired, excessive, or long-lived client credentials" (full source read) | `tests/maester/entra/Test.MT.1208.ps1` | Declared `Medium`, runtime detail call for this condition emits `-Severity 'High'` (same declared/shipped mismatch as MT.1118) | `nist-800-53-r5:IA-5` |
| C17b | Blueprints | Client credential validity exceeds 730 days (configurable `$MaxValidityDays`) | MT.1208 (same file, second condition) | `tests/maester/entra/Test.MT.1208.ps1` | as above | `nist-800-53-r5:IA-5` |
| C17c | Blueprints | More than 2 active client secrets (configurable `$MaxActiveSecrets`) | MT.1208 (same file, third condition) | `tests/maester/entra/Test.MT.1208.ps1` | as above | `nist-800-53-r5:IA-5` |
| C17d | Blueprints | Client secret retained alongside a federated identity credential (a live fallback that defeats FIC migration) | MT.1208 (same file, fourth condition) | `tests/maester/entra/Test.MT.1208.ps1` | as above | `nist-800-53-r5:IA-5` |
| C18 | Agent identities | High-risk Graph app permission grant | MT.1223 | `tests/maester/entra/Test.MT.1223.ps1` | High | `nist-800-53-r5:AC-6` |
| C19 | Agent identities | Privileged directory role on agent identity | MT.1209 | `tests/maester/entra/Test.MT.1209.ps1` | n/a | n/a |
| C20 | Agent identities | Privileged role / role-assignable-group membership for an agent **user** | MT.1210 | `tests/maester/entra/Test.MT.1210.ps1` | n/a | n/a |
| C21 | Blueprints | allAllowed inheritable permissions (delegated scopes or app roles) | MT.1211 | `tests/maester/entra/Test.MT.1211.ps1` (full source read) | High | `nist-800-53-r5:AC-6` |
| C22 | Blueprints | Foreign/multi-tenant blueprint holding privileged directory role | MT.1207 | `tests/maester/entra/Test.MT.1207.ps1` | n/a | n/a |
| C23 | Blueprint principals | Application roles exposed without requiring assignment | MT.1212 — "should require assignment for the application roles they expose" | `tests/maester/entra/Test.MT.1212.ps1` | n/a | n/a |
| C24 | Blueprints | Wildcard or plain-HTTP redirect URIs | MT.1213 — "should not use wildcard or plain-http redirect URIs" | `tests/maester/entra/Test.MT.1213.ps1` | n/a | n/a |
| C25 | Agent identities | Never signed in / inactive beyond 180 days (default, configurable `$MaxInactiveDays`), including a "fully dormant fleet with a live parent blueprint credential" compound signal | MT.1206 | `tests/maester/entra/Test.MT.1206.ps1` (full source read) | Medium | `nist-800-53-r5:AC-2(3)` |
| C26 | Blueprint creation governance | Users able to create Agent Identity Blueprints without restriction | MT.1225 — "Users should not be able to create Agent Identity Blueprints" | `tests/maester/entra/Test.MT.1225.ps1` | n/a | n/a |
| C27 | Conditional Access | No CA policy blocking high-risk agent sign-ins | MT.1181 | `tests/maester/entra/Test.MT.1181.ps1` | High | `nist-800-53-r5:AC-2(12)`, `AC-2(13)` |
| C28 | Privileged apps (not agent-specific, but named overlap to confirm) | App registrations with privileged Graph permissions that still have owners | MT.1077 | `tests/maester/xspm/Test.MT.1077.ps1` | Medium | `nist-800-53-r5:AC-6` |
| C29 | Privileged apps | App registrations with privileged directory roles that still have owners | MT.1078 | `tests/maester/xspm/Test.MT.1078.ps1` | Medium | `nist-800-53-r5:AC-6` |
| C30 | Privileged apps | Privileged API permissions on service principals, unused | MT.1079 | `tests/maester/xspm/Test.MT.1079.ps1` | Medium | `nist-800-53-r5:AC-6` |

**Ruled out as NOT agent-related** (the original subagent pass wrongly included this
as part of the MT.12xx range): **MT.1252** — real title is "Apps scoped with
Exchange RBAC for Applications should not hold the same or a broader permission
tenant-wide in Microsoft Entra ID." This is a generic Exchange-RBAC privilege-escalation
check, unrelated to Agent ID. Confirmed directly from source; excluded from this
pack's scope entirely.

**`Test-MtCaAgentRiskBlockPolicy`** — not a separate function; the described logic
lives inline inside `Test.MT.1181.ps1` itself (reads `Get-MtConditionalAccessPolicy`,
checks `conditions.agentIdRiskLevels -match 'high'` and
`grantControls.builtInControls -match 'block'`). There is no standalone
`Test-MtCaAgentRiskBlockPolicy` function to reuse or extend; MT.1181 **is** that
logic.

## Skills and MCP — surface redefinition (replaces the earlier Skills section)

**Corrected 2026-11-05 with a live validation run** (see `phase0-notes.md`, surface 3). An
earlier `GET /v1.0/copilot/admin/catalog/packages?$expand=packageElementDetail` call against the
test tenant returned `403 Forbidden`. That 403 was a **consent gap, not a license gate**: once
`CopilotPackages.Read.All` was properly consented, `GET /v1.0/copilot/admin/catalog/packages`
succeeded against this (F7-licensed) tenant with no separate Agent 365 license observed — reading
this endpoint may require a Microsoft Agent 365 license depending on tenant, but this tenant's
403 was resolved by consent alone. There is also no `packageElementDetail` expand parameter (that
400s); the real per-package detail call is `GET /v1.0/copilot/admin/catalog/packages/{id}`, which
returns an `elementDetails` array.

The confirmed live schema:
- `copilotPackage.elementTypes` (String collection, list response) — confirmed real values in this
  tenant include `AgentConnectors` (69 packages) and `MCPServers` (37 packages), not just
  `Bot`/`DeclarativeAgent`/`CustomEngineCopilot`.
- `elementDetails[].elements[].definition` (per-package detail, a JSON string) — for
  `AgentConnectors`/`MCPServers` entries, contains `toolSource.remoteMcpServer.mcpServerUrl`,
  `authorization.type`, and `mcpToolDescription.tools[]` (each tool: `name`, `description`,
  `inputSchema`, `annotations.{readOnlyHint,destructiveHint,idempotentHint,openWorldHint}`).
- Separately, Microsoft's "Build plugins for Copilot Cowork" packaging guide describes a
  **manifest-level** `agentSkills` section (`SKILL.md` files) as part of a Cowork plugin package
  file; this is confirmed as a real `elementTypes` value (seen live) but is a distinct concept from
  MCP/connector tools.

**Conclusion:** MCP server URL/host and tool-review findings against `AgentConnectors`/
`MCPServers` are a real, queryable, Graph-only data source — **testable via Graph alone, confirmed
live**, not Defender-dependent. This also means G12–G14 (relabeled Topic hygiene above) are the
only currently-evidenced findings for the Copilot Studio "Topics" side of this surface.

**Updated 2026-11-06:** all three identified findings against this surface are now built and
live-validated: MCP host allowlist (G21b, `MP.AIGOV.1010`), destructive/open-world MCP tool in a
tenant-wide package (G23, `MP.AIGOV.1011`), and weak-description/unreviewed-exposure `AgentSkills`
(G24, `MP.AIGOV.1012`) — the first finding built against the `SKILL.md`-level `agentSkills` value
confirmed to exist in this tenant's catalog.

## CIS Controls v8.1 and CISA agentic-AI risk category mapping (Supporting alignment)

Per review feedback, this matrix adds CIS Controls v8.1 Safeguards and the CISA/NSA/
Five-Eyes *Careful Adoption of Agentic AI Services* risk categories (privilege,
design and configuration, behavioral, structural, accountability) as a second,
explicitly **Supporting alignment** layer — never Direct requirement — sourced from
`chadmcox/Copilot`'s own `Agent and Tools Health Check/Cowork/plugin/skills/agent-tools-health/references/guidance.md`.
That file states plainly: "Which safeguard and which CISA category each check maps
to is this repo's judgment, not something CIS or CISA published" — the same caveat
applies here. NIST CSF 2.0 is dropped entirely per your decision; NIST 800-53 Rev. 5
stays, already cited per-row above where Maester ships a Control.

| Finding grain (maps across one or more G/P/C rows above) | CIS v8.1 Safeguard(s) | CISA risk category |
|---|---|---|
| Agent available to everyone / assigned to users not groups (G2a, G3, C1) | 6.1, 6.8 | Privilege |
| No sponsor/owner, single sponsor, orphaned ownership (G5, C14, C15, C16) | 5.1, 5.5 | Accountability |
| High-privilege Graph app permissions (C18) | 3.3, 5.4 | Privilege |
| allAllowed inheritable permissions (C21) | 3.3, 6.8 | Privilege, structural |
| Client secret / expired / excessive / long-lived / nearing-expiry credential (G14a built as `MP.AIGOV.1009`, P2, C17a–C17d) | 4.1 | Design and configuration |
| No CA policy for agents / report-only / no high-risk block (C27) | 4.1, 6.7 | Design and configuration, behavioral |
| Unclear name/description (G4) | 2.1, 5.5 | Accountability |
| Dormant/stale agent or Topic, including usage-report adoption (G1, G14 via Topic hygiene, C5) | 5.3, 6.2 | Accountability |
| Blocked package with pending request (G22) | 6.1 | None (CIS/CISA do not map a control to request-queue hygiene) |
| Classic Copilot Studio SP not registered in Agent ID (G7) | 1.1, 2.1 | Accountability |
| Cloud agent found by Defender but not in the Agent 365 registry (G19) | 1.1, 2.1, 2.3 | Accountability |
| MCP server over plain HTTP (G20, built as `MP.AIGOV.1008`) | 3.10, 15.1 | Design and configuration |
| MCP server on a non-allowlisted host (G21b, built as `MP.AIGOV.1010`) | 15.1, 15.2 | Design and configuration |
| Destructive/open-world MCP tool in a tenant-wide package (G23, built as `MP.AIGOV.1011`) | 3.3, 6.8 | Privilege |
| Weak-description or unreviewed tenant-wide agent skill (G24, built as `MP.AIGOV.1012`) | 4.1, 6.8 | Design and configuration |
| Maker (author) authentication on a connection (C6 / MT.1118) | 4.1 | Design and configuration |
| No DLP policy covering a connector or environment (G8, G11) | 2.5, 15.1 | Design and configuration |
| MCP server using weak or no authentication (G25, built as `MP.AIGOV.1016`) | 3.10, 15.1 | Design and configuration |
| No Conditional Access coverage for agent identities (G26, built as `MP.AIGOV.1017`) | 4.1, 6.7 | Design and configuration, behavioral |
| Agent identity at risk, not remediated or dismissed (G27, built as `MP.AIGOV.1018`) | 6.7 | Behavioral |
| Agent identity has user-consented delegated permissions (G28, built as `MP.AIGOV.1019`) | 3.3, 6.8 | Privilege |

## Items not yet independently verified (flagged, do before finalizing)

- C19, C20, C23, C24, C26: titles confirmed directly from the
  `Title =` attribute in source, but full trigger-condition bodies and `Control`
  attributes were **not** re-read line-by-line this run (time-boxed to the
  highest-ambiguity items: MT.1206, MT.1207, MT.1211, MT.1223, MT.1205, MT.1208,
  MT.1118, which were fully verified this pass). Before publishing the final
  matrix, read the remaining bodies the same way to confirm exact Severity/Control/
  Skip behavior.
- The Skills/MCP `elementType` taxonomy above is confirmed live against the test
  tenant (2026-11-05); see `phase0-notes.md` surface 3 for the full schema.
- G11, G17, G18: framework/API details flagged inline as unverified this run.

## Framework gap review (2026-11-18)

Checked the pack against CISA SCuBA (`aad.md` MS.AAD.9.1, released in ScubaGear 2.0.0; `si.md` "SI / SI Agents"
baseline MS.SI.1.1–13.6, a **draft** on ScubaGear `main` @ `18f7930` with rationale and instructions still "TBD";
`powerplatform.md`), CISA/NSA/Five Eyes *Careful Adoption of Agentic AI Services* (May 1, 2026), CIS M365
Foundations Benchmark v7.0.0 (May 19, 2026; only AI item is 3.2.3), CIS Controls v8.1 AI companion guides (LLM,
Agents, MCP; Apr 20, 2026), and NIST AI RMF 1.0 / AI 600-1. NIST COSAiS and IR 8596 are still drafts and aren't
mapped.

### Built this round

| # | Finding | Test | Data source | Framework mapping (Supporting) |
|---|---|---|---|---|
| G30 | AI Administrator, Agent ID Administrator or Agent Registry Administrator held permanently, by a guest or app, or by too many people | `MP.AIGOV.1034` | Graph `roleAssignmentScheduleInstances` (fallback `roleAssignments`), `RoleManagement.Read.Directory` | cisa-scuba MS.SI.6.4 (draft); nist-800-53-r5:AC-6(5), AC-2(7) |
| P2 → built | Blueprint authenticates with a client secret | `MP.AIGOV.1035` | Graph `applications/microsoft.graph.agentIdentityBlueprint` | MS.SI.2.1 (draft); IA-5 |
| G31 | Enabled agent identity with no active sponsor | `MP.AIGOV.1036` | Graph `.../microsoft.graph.agentIdentity/sponsors` | MS.SI.3.1 (draft); AC-2 |
| G19 → built | Defender-discovered agent with no Entra identity | `MP.AIGOV.1037` | Graph `security/runHuntingQuery` on `AgentsInfo`, `ThreatHunting.Read.All` | CISA agentic (registry reconciliation); CM-8; AI RMF GOVERN 1.6 |
| G32 | MCP tool definition changed or added since approval | `MP.AIGOV.1038` | Package detail `elementDetails`, baseline in `AIGOV.McpToolBaseline` | CISA agentic (allow-list tools and versions); CIS MCP Companion Guide; CM-2, CM-3 |
| G33 | MCP tool description steers the model, or tool has no behavior annotations | `MP.AIGOV.1039` | Package detail `elementDetails` | CISA agentic (standardize tool descriptions); SI-10 |
| G34 | No sites-and-groups sensitivity label, or duplicate label names | `MP.AIGOV.1040` | Graph v1.0 `security/dataSecurityAndGovernance/sensitivityLabels`, `SensitivityLabel.Read` | MS.SI.6.1, 6.3, 7.2, 7.4 (draft); AC-16 |
| G35 | Foreign agent blueprint principal from an unverified publisher | `MP.AIGOV.1041` | Graph `agentIdentityBlueprintPrincipal` (`verifiedPublisher` population **unverified**) | CISA agentic (third-party registry); SR-3, SA-9 |
| G36 | Web search in Copilot on for everyone | `MP.AIGOV.1042` | Graph beta `copilot/admin/policySettings/microsoft.copilot.allowwebsearch`, delegated `CopilotPolicySettings.Read` only | MS.SI.10.3 (draft); AC-4 |
| G37 | Enforced Copilot DLP policy doesn't turn on all four Copilot protections | `MP.AIGOV.1043` | S&C `Get-DlpCompliancePolicy` / `Get-DlpComplianceRule` (`RestrictAccess` ExcludeContentProcessing, `RestrictWebGrounding`, `FromScope`) | MS.SI.10.2, 10.3, 10.5, 10.6 (draft); CIS M365 3.2.3 (adjacent); AC-4 |
| G38 | CopilotInteraction audit records kept less than required | `MP.AIGOV.1044` | S&C `Get-UnifiedAuditLogRetentionPolicy` | MS.SI.5.1, 11.4 (draft); AU-11 |
| G39 | Azure OpenAI / AI Services account allows key auth or public access, or Defender for AI Services is off | `MP.AIGOV.1045` | Azure Resource Graph + ARM `Microsoft.Security/pricings/AI` | IA-2, SC-7, SI-4 |

### Live review (Nov 18, 2026)

The local pack was run with the pinned Maester source and delegated connections, with raw evidence kept
outside tracked files. Graph batching was not disabled: the 1032 diagnostic used batches. Historical
batch bodies were not captured; the accepted source audit shows GET-only inner requests for this test.
A directory-audit read for the signed-in user over the live-run window returned zero entries. Request-body
logging was verified offline before resuming. A skip or empty inventory is not validation of the missing
branch. The following observations limit the framework claims:

| Tests | Confirmed or corrected | Remaining limit |
|---|---|---|
| 1034 | 104 active assignments were `Assigned` without an end date; all three roles exceeded three holders. No eligible schedule instances were returned. Expanded users omitted `userType` and nested selection failed; added explicit user reads. Independent reads found 58 distinct member users. | No guest or app assignment was present. |
| 1035-1036 | Two of six blueprints had active secrets; the application federated-credentials path worked for the derived blueprint type. All 11 enabled identities had enabled user sponsors. | Certificate and inactive-sponsor cases were not present. |
| 1037 | Corrected case-sensitive hunting columns to `Name`, `EntraAgentID`, `EntraBlueprintID`, with aliases preserving result fields. Independent and corrected test results agreed: 421 of 431 cloud rows had neither Entra identifier; three local rows were informational. Query errors no longer impersonate a missing-table/license skip. | A populated table does not exercise the unavailable-table case. 428 flagged rows were platform `Other`; follow-up added lifecycle/draft filters, `column_ifexists` for both column spellings, a per-platform count and `AIGOV.ExcludedAgentPlatforms` (unit-tested, needs a live rerun). |
| 1038-1039 | Both reachable MCP packages supplied only a server URL, with no tool definitions. Corrected the unsupported zero-tool pass and unusable baseline to explicit missing-metadata skips, including partial metadata coverage. | Live fingerprint approval/change/stability and manual steering-hit review could not run; no remote MCP server was contacted. Follow-up: packages that do list tools are now evaluated; packages without definitions are named and the result is a partial-check skip unless something fails. |
| 1040 | Eight roots and seven inline sublabels; four of 15 enabled labels applied to sites/groups. `applicableTo` was a string; root `isDefault` values were false. | No duplicate-name case was present. |
| 1041 | `$select=verifiedPublisher` succeeded on eight blueprint principals, but every publisher ID was empty. Added explicit skips for unsupported selection or all-empty IDs instead of inferring publisher verification. | No foreign principal or populated publisher ID was available; publisher classification remains unvalidated. |
| 1042 | Raw singleton response contained `value=null`, `policyId=null`, matching the user's Apps admin center confirmation of Not configured. Disabled Maester paging to preserve the scalar setting and policy metadata rather than unwrapping `value`. | No configured setting value was available live. |
| 1043 | Five policies, nine rules; the only Copilot policy was simulation. Actual `Locations` was a JSON string containing `Copilot.M365`; the rule had a sensitive-information array and `RestrictAccess` `UploadText=Block`. The user confirmed simulation and prompt blocking in Purview. Updated synthetic fixtures, prompt-action matching, and same-action block pairing. | The live skip is not proof of enforced protections. |
| 1044 | Independent native command returned zero retention policies, confirming the missing-policy finding. | `RecordTypes`, `Enabled` availability and duration values cannot be checked without an object. |
| 1045 | Resource Graph returned no accounts, and independent subscription enumeration found zero accessible subscriptions. | The empty-inventory pass proves neither account configuration nor pricing; no subscription was available for a pricing GET. |

Earlier-test outcome changes were compared with their dated banners. For 1009, one secret moved from outside
the 30-day window to approximately 30 days remaining, consistent with elapsed time. The 1020 reachability
revision already documented in its banner explains exclusion of the former unreachable finding. Current
1011 candidates are not tenant-wide; 1021 now finds assigned groups; 1025 reports 21 configured policies;
1027 reports only informational dynamic groups. Those are current-input observations, not proof of who
changed the tenant or when; historical raw snapshots are unavailable. No old-test code was changed to force
these outcomes.

An earlier 1032 rerun passed for 5,000 processed members but skipped sign-ins and reported 6,459 members
beyond the cap. A later diagnostic timed out at 900 seconds with Graph throttling, superseding that pass.
A separate single-user read and a filtered 15-user collection read succeeded. Replaced per-member sign-in
requests with filtered collections of at most 15 IDs, retaining the member cap and existing findings.
The regression checks the boundary and that every requested member appears in exactly one filter.
The corrected live run returned all 5,000 requested activity records and flagged 30 members: 23 with
stale successful sign-ins and seven older accounts with no recorded history. Independent reads confirmed
all 30 findings. Five sampled null histories remained null on direct reads; a tenant-wide cutoff query
returned 49 users and none of the 4,976 null-history IDs. Added account creation time: seven null-history
accounts were older than 90 days and 4,969 were new accounts, too early to judge. No history/age was unknown.
All seven older null-history accounts were created after April 2020 and stayed null on direct reads.
Seeded origin was not established; null history alone does not establish how an account was created.
The report now counts missing-history, new-account, unknown and fallback cases explicitly. When successful
history is absent, the later interactive/non-interactive attempt is used; this fallback is unit-tested but
was not present live. The 6,459 memberships reported beyond the member cap remain unchecked.
Follow-up: the cap is now the `AIGOV.MaxSpendingPolicyMembers` setting (`0` = no cap), skipped members are
counted once each rather than once per membership, and the result leads with the coverage percentage. A clean
run past the cap skips as partial coverage instead of passing. Unit-tested; needs a live rerun with the cap
raised or removed.

### Covered by Maester core (missing from the tables above)

| # | Finding | Existing test | Notes |
|---|---|---|---|
| C31 | Unified audit log ingestion on | MT.1172 | MS.SI.6.2 (draft) |
| C32 | Sensitivity labels published for files used by Copilot | MT.1173 | |
| C33 | Insider Risk policy for risky AI usage on | MT.1174 | MS.SI.12.3 (draft) |
| C34 | Enabled, non-simulation DLP policy for the Copilot location | MT.1175, CIS.M365.3.2.3 | `MP.AIGOV.1043` checks which protections its rules turn on |
| C35 | Retention policy for the Microsoft Copilot location | MT.1176 | Other AI app locations stay manual |
| C36 | Risky AI agents blocked by Conditional Access | MT.1181 | Equals CISA SCuBA MS.AAD.9.1 (released) |

### Reviewed and not built

| Candidate | Reason |
|---|---|
| Agent identities covered only by static Conditional Access includes | Already covered: `MP.AIGOV.1017` reports this as Partial (Medium) |
| Copilot Studio agent traffic not under Global Secure Access web filtering / prompt injection protection | Prompt policy type not documented in Graph; README manual check |
| Agent identity with Graph app permissions and no expiring access package | Access package assignment target shape for agent identities not verified |
| Restricted Content Discovery on unreviewed sites | Needs a per-site business decision; README manual check |
| Retention for Enterprise AI apps / Other AI apps; Communication Compliance for AI | App identifiers and location values not documented; README manual checks |
| Copilot Studio public publishing, channels, knowledge protection, threat detection error behavior; Power Platform DLP and tenant isolation; PAYG billing | No Maester connection packs can use (Dataverse reader is internal; no Power Platform admin connection); README manual checks |

### Mapping caveat

The CIS v8.1 and CISA risk-category table above is still this repo's judgment. CIS now publishes official LLM, Agent
and MCP companion guides; remap against them when you can read the safeguard text. `MS.SI.*` IDs come from an
unreleased draft and may change before ScubaGear ships the baseline.
