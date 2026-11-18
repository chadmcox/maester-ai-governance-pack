Reconciles Microsoft Defender's agent inventory with Microsoft Entra. Runs an advanced hunting query through Graph
(`POST /security/runHuntingQuery`, via Maester's `Invoke-MtGraphSecurityQuery`) against the `AgentsInfo` table,
latest record per agent, deleted agents dropped.

A cloud agent fails when both `EntraAgentId` and `EntraBlueprintId` are empty: Defender sees it, but it has no Entra
identity to govern with Conditional Access, sponsors or ID Protection. Agents on the `LocalAgents` platform (tools
Defender for Endpoint found on devices) are reported for information only.

`AgentsInfo` replaced `AIAgentsInfo` in June 2026. The table needs Microsoft Defender XDR with Microsoft Agent 365;
without it the test skips. This is your coverage matrix row **G19**, now reachable through Graph.

Framework: CISA/NSA *Careful Adoption of Agentic AI Services* (trusted registry reconciled against live agents, deny
unregistered agents); NIST 800-53 CM-8; AI RMF GOVERN 1.6.

> [!NOTE]
> **Not yet validated** against a live tenant. Unit-tested only (Pester, mocked data). Run it against your
> tenant and check the result before relying on it.

#### Remediation action

Register each agent with Microsoft Entra Agent ID, or remove it from the platform it runs on.

#### Related links

- [AgentsInfo table](https://learn.microsoft.com/defender-xdr/advanced-hunting-agentsinfo-table)
- [Discover AI agents with Microsoft Defender](https://learn.microsoft.com/defender-xdr/security-for-ai/ai-agent-inventory)

<!--- Results --->
%TestResult%
