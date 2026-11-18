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

#### Remediation action

Register each agent with Microsoft Entra Agent ID, or remove it from the platform it runs on.

#### Related links

- [AgentsInfo table](https://learn.microsoft.com/defender-xdr/advanced-hunting-agentsinfo-table)
- [Discover AI agents with Microsoft Defender](https://learn.microsoft.com/defender-xdr/security-for-ai/ai-agent-inventory)

<!--- Results --->
%TestResult%
