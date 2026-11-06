> [!NOTE]
> **Validated** 2026-11-06 against a real Microsoft 365 test tenant (F7-licensed), and re-validated
> after adding scheme/host-only redaction and failure counting. The run correctly **Passed** (true
> negative): 37 packages had an MCP server element, and all 37 observed `mcpServerUrl` values were
> `https://` (sample hosts: `mcp.maestrolabs.com`, `mcp.tavily.com`, `mcp.asana.com`, `mcp.xero.com`,
> `mcp.factset.com`). This confirms the `elementDetails` `AgentConnectors` schema and the
> URL-scheme check both work; a zero-finding result here is the expected negative case for this
> tenant, not evidence the check is broken. The redaction and failure-counting logic ran without
> error, but no package in this tenant triggered a detail-call or parse failure, so that specific
> code path has not been exercised live.

Checks whether any MCP server endpoint referenced by an installed package is reachable over plain
`http://` instead of `https://`. The URL comes from the per-package detail call (`GET
/copilot/admin/catalog/packages/{id}`), specifically the `elementDetails` entry with `elementType`
`AgentConnectors`, whose `elements[].definition` (a JSON string) contains
`toolSource.remoteMcpServer.mcpServerUrl`. An agent calling an MCP server over plain HTTP sends tool
inputs and outputs — which may include sensitive data pulled into the conversation — without
transport encryption, exposing them to interception on the network path.

The result table never shows the full `mcpServerUrl`: only the scheme and host (e.g.
`http://example.com`) are reported, since the path, query, fragment, and any embedded userinfo may
carry tenant- or tool-specific identifiers. If a package's detail call or definition parse fails,
it is counted but does not fail the whole test; the result notes how many packages could not be
evaluated. If every package with an MCP server element fails to evaluate, the test skips with
`Error` rather than reporting a false pass.

#### Remediation action

Contact the MCP server operator (or the package publisher) and request an `https://` endpoint, or
remove the package until one is available.

#### Related links

- [Get Copilot package](https://learn.microsoft.com/graph/api/copilotadmin-get-package?view=graph-rest-1.0)

<!--- Results --->
%TestResult%
