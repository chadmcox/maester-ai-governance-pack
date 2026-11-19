An MCP server with no authentication lets anyone who finds it call its tools, and weak authentication can't tell your agent apart from an attacker. Agents then pass user data to a server that can't prove who is calling it.

#### Remediation action

Reconfigure the MCP server to authenticate with `OAuthPluginVault` or
`DynamicClientRegistration` instead of a static key or no authentication at all, and prioritize any
server flagged High or Medium that is also available or deployed tenant-wide.

#### Related links

- [Configure remote MCP servers for Microsoft 365 Copilot plugins](https://learn.microsoft.com/microsoft-365/copilot/extensibility/configure-plugin-mcp-servers)
- [Get Copilot package](https://learn.microsoft.com/graph/api/copilotadmin-get-package?view=graph-rest-1.0)
- [How this check works](https://github.com/chadmcox/maester-ai-governance-pack/blob/main/docs/how-checks-work.md#mp-aigov-1016)

<!--- Results --->
%TestResult%
