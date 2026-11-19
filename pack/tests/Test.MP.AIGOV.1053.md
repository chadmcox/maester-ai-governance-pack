MCP servers set up in Copilot Studio agents or in developer tools on devices don't appear in the agent catalog, so they escape the catalog checks. They still receive your data and run actions, so they need the same rules: encrypted connections, trusted hosts and approval before tools run on published agents.

#### Remediation action

- Move MCP servers to HTTPS endpoints on hosts you've reviewed, and remove the ones you haven't.
- In Copilot Studio, open the agent's **Tools**, select the MCP server, and require the user to confirm before
  tools run, then republish.
- For local agents, change the agent's own MCP configuration on the device.

#### Related links

- [Connect your agent to an existing MCP server (Copilot Studio)](https://learn.microsoft.com/microsoft-copilot-studio/mcp-add-existing-server-to-agent)
- [Discover local AI agents with Microsoft Defender for Endpoint](https://learn.microsoft.com/defender-endpoint/discover-local-ai-agents)
- [AgentsInfo table](https://learn.microsoft.com/defender-xdr/advanced-hunting-agentsinfo-table)
- [How this check works](https://github.com/chadmcox/maester-ai-governance-pack/blob/main/docs/how-checks-work.md#mp-aigov-1053)

<!--- Results --->
%TestResult%
