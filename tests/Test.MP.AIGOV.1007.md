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

#### Remediation action

Scope the package's availability and deployment to a specific group instead of the whole tenant, and
confirm the rollout plan with the agent's sponsor before widening it again.

#### Related links

- [List Copilot packages](https://learn.microsoft.com/graph/api/copilotadmin-list-packages?view=graph-rest-1.0)

<!--- Results --->
%TestResult%
