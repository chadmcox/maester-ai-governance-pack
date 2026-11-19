Microsoft Defender assesses each agent and flags real exposure, such as running on a vulnerable device or sitting unused while keeping its access. These indicators point to the agents most likely to be misused or attacked, so they should be dealt with first.

#### Remediation action

In the Microsoft Defender portal, go to **Assets** > **AI agents**, open each agent listed, and review its risk
indicators, evidence and security recommendations. Fix the cause (patch the device, retire a dormant agent,
reduce what a published agent can reach) or block the agent.

#### Related links

- [Discover AI agents and assess security posture using Microsoft Defender](https://learn.microsoft.com/defender-xdr/security-for-ai/ai-agent-inventory)
- [AI agent posture risk in Microsoft Defender](https://learn.microsoft.com/defender-xdr/security-for-ai/ai-agent-risk-assessment)
- [AgentsInfo table](https://learn.microsoft.com/defender-xdr/advanced-hunting-agentsinfo-table)
- [How this check works](https://github.com/chadmcox/maester-ai-governance-pack/blob/main/docs/how-checks-work.md#mp-aigov-1052)

<!--- Results --->
%TestResult%
