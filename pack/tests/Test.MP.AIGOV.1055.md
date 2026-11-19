A local AI agent that approves its own actions can run commands, change files and reach systems with the user's access, with nobody confirming each step. One bad instruction, from a prompt or from content it reads, can do real damage on that device.

#### Remediation action

Turn off auto-approve in each agent's settings on the device, or block the
agent with your endpoint management tools. Investigate agents whose host process isn't trusted.

#### Related links

- [Discover local AI agents with Microsoft Defender for Endpoint](https://learn.microsoft.com/defender-endpoint/discover-local-ai-agents)
- [AgentsInfo table](https://learn.microsoft.com/defender-xdr/advanced-hunting-agentsinfo-table)
- [How this check works](https://github.com/chadmcox/maester-ai-governance-pack/blob/main/docs/how-checks-work.md#mp-aigov-1055)

<!--- Results --->
%TestResult%
