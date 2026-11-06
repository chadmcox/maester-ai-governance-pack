Checks each MCP server's `toolSource.remoteMcpServer.authorization.type`, read from the same
per-package detail call (`GET /copilot/admin/catalog/packages/{id}`) and JSON path
`MP.AIGOV.1008`/`MP.AIGOV.1010`/`MP.AIGOV.1011` already use. The documented values (Learn:
["Configure remote MCP servers for Microsoft 365 Copilot plugins"](https://learn.microsoft.com/microsoft-365/copilot/extensibility/configure-plugin-mcp-servers))
are `None`, `OAuthPluginVault`, `ApiKeyPluginVault`, `DynamicClientRegistration`, `AzureKeyVault`,
and `ConnectionVault` (developer preview) — not literal strings like "anonymous" or
"shared-secret". This test reports every distinct value it actually sees in the tenant before
classifying anything, so an unexpected or newly introduced value is visible rather than silently
bucketed.

Classification: `None` is **High** — the server declares no authentication at all. A missing or
unparseable `authorization` object (no type in the manifest at all, rather than a well-formed
object whose type is the documented literal `None`) is reported separately as **Unspecified**, also
**High** — neither represents an enforced identity flow, but an admin reviewing the observed-values
list should be able to tell a deliberately anonymous MCP server from one whose manifest is missing
or malformed. `ApiKeyPluginVault` and `AzureKeyVault` are **Medium** — both ultimately
authenticate with a stored static secret rather than an identity-based token flow; `AzureKeyVault`
only changes where that secret is stored. `ConnectionVault` (developer preview) is treated the same
as `AzureKeyVault` pending broader documentation. `OAuthPluginVault` and
`DynamicClientRegistration` are a pass — both are Entra/OAuth identity flows. Any finding is
reported as worse when its package is available or deployed tenant-wide, using the same
`availableTo`/`deployedTo` signal as `MP.AIGOV.1007`/`MP.AIGOV.1011`. Only the MCP server's scheme
and host are ever reported, never the full `mcpServerUrl`, matching `MP.AIGOV.1008`. Detail-call and
definition-parse failures are counted the same way as those tests: a partial failure is noted in
the result, and a total failure skips with `Error` instead of reporting a false pass.

> [!NOTE]
> **Validated** 2026-11-06 against a real Microsoft 365 test tenant (F7-licensed). The run
> correctly **Passed** (true negative): 38 packages with an MCP server element were checked, and
> the only `authorization.type` values observed in this tenant were `DynamicClientRegistration`
> and `OAuthPluginVault` -- both pass. No `None`/missing, `ApiKeyPluginVault`,
> `AzureKeyVault`, or `ConnectionVault` values were present, so the Medium/High paths were not
> exercised against real data this run.

#### Remediation action

Reconfigure the MCP server to authenticate with `OAuthPluginVault` or
`DynamicClientRegistration` instead of a static key or no authentication at all, and prioritize any
server flagged High or Medium that is also available or deployed tenant-wide.

#### Related links

- [Configure remote MCP servers for Microsoft 365 Copilot plugins](https://learn.microsoft.com/microsoft-365/copilot/extensibility/configure-plugin-mcp-servers)
- [Get Copilot package](https://learn.microsoft.com/graph/api/copilotadmin-get-package?view=graph-rest-1.0)

<!--- Results --->
%TestResult%
