Checks whether any MCP server endpoint referenced by an installed package is hosted on a domain
outside a configurable allowlist (`-AllowedHosts`). The URL comes from the per-package detail call
(`GET /copilot/admin/catalog/packages/{id}`), specifically the `elementDetails` entry with
`elementType` `AgentConnectors`, whose `elements[].definition` (a JSON string) contains
`toolSource.remoteMcpServer.mcpServerUrl`. A host matches the allowlist if it equals an entry
exactly or is a subdomain of one.

The default allowlist covers common Microsoft domains only. Every third-party vendor your tenant
has approved should be added to the allowlist explicitly — until then, this check reports them as
unreviewed. The result table never shows the full `mcpServerUrl`: only the scheme and host are
reported, matching `MP.AIGOV.1008`'s redaction. Detail-call and definition-parse failures are
counted the same way as `MP.AIGOV.1008`: a partial failure is noted in the result, and a total
failure skips with `Error` instead of reporting a false pass.

> [!NOTE]
> **Validated** 2026-11-06 against a real Microsoft 365 test tenant (F7-licensed). With the default
> (Microsoft-only) allowlist, the run correctly **Failed** (true positive): all 37 packages with an
> MCP server element resolved to a non-Microsoft host (no Microsoft-hosted MCP server exists in this
> tenant today). This is expected for an unreviewed allowlist, not evidence of a broken check — add
> each reviewed vendor host to `-AllowedHosts` as it's approved.

#### Remediation action

Review the MCP server's host and publisher. If it's a reviewed, approved vendor, add its host to
your `-AllowedHosts` list. If it isn't, investigate why the package was installed and consider
removing it until it has been reviewed.

#### Related links

- [Get Copilot package](https://learn.microsoft.com/graph/api/copilotadmin-get-package?view=graph-rest-1.0)

<!--- Results --->
%TestResult%
