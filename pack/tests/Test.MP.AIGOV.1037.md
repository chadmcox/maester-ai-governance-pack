An agent with no Microsoft Entra identity can't be covered by Conditional Access, ID Protection, sponsors or access reviews. Agents that Defender finds but Entra doesn't know about are outside your identity controls.

#### Remediation action

Register each agent with Microsoft Entra Agent ID, or remove it from the platform it runs on.

#### Related links

- [AgentsInfo table](https://learn.microsoft.com/defender-xdr/advanced-hunting-agentsinfo-table)
- [Discover AI agents with Microsoft Defender](https://learn.microsoft.com/defender-xdr/security-for-ai/ai-agent-inventory)
- [How this check works](https://github.com/chadmcox/maester-ai-governance-pack/blob/main/docs/how-checks-work.md#mp-aigov-1037)

<!--- Results --->
%TestResult%
