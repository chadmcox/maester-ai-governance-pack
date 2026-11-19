Older Copilot Studio agents run as ordinary service principals. They don't get the sponsors, lifecycle controls, agent-specific Conditional Access and ID Protection that Microsoft Entra Agent ID gives newer agents, so they're easy to forget and harder to govern.

#### Remediation action

For each flagged agent, decide its disposition: retire it if unused, recreate it with Agent ID if
lightly used, or keep it running as-is (with its own sponsor/owner hygiene) if it is a busy production
agent until Microsoft ships an automated migration path.

#### Related links

- [List servicePrincipals](https://learn.microsoft.com/graph/api/serviceprincipal-list?view=graph-rest-1.0)
- [How this check works](https://github.com/chadmcox/maester-ai-governance-pack/blob/main/docs/how-checks-work.md#mp-aigov-1005)

<!--- Results --->
%TestResult%
