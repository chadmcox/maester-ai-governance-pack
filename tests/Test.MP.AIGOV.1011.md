Checks whether any MCP tool with a `destructiveHint` or `openWorldHint` annotation is reachable
through a package that's available or deployed tenant-wide (`availableTo` indicating
`allowedForAll`, or `deployedTo` indicating `acquiredForAll` — the same tenant-wide signal
`MP.AIGOV.1007` uses). The tool annotations come from the per-package detail call (`GET
/copilot/admin/catalog/packages/{id}`), specifically the `elementDetails` entry with `elementType`
`AgentConnectors`, whose `elements[].definition` (a JSON string) contains
`toolSource.remoteMcpServer.mcpToolDescription.tools[].annotations`.

A `destructiveHint: true` tool can make an irreversible change; an `openWorldHint: true` tool can
interact with an open-ended, not-fully-enumerable set of external entities. Either one, combined
with the tool being reachable by everyone in the tenant by default, is materially riskier than the
same tool scoped to a reviewed pilot group. Detail-call and definition-parse failures are counted
the same way as `MP.AIGOV.1008`/`MP.AIGOV.1010`: a partial failure is noted in the result, and a
total failure skips with `Error` instead of reporting a false pass.

> [!NOTE]
> **Validated** 2026-11-06 against a real Microsoft 365 test tenant (F7-licensed). The run
> correctly **Failed** (true positive): found MCP tools with `openWorldHint: true` inside a
> tenant-wide package ("Moody's Credit MCP", `type: thirdParty`, `availableTo: allowedForAll`),
> confirming both the tenant-wide filter and the tool-annotation schema work against real data.

#### Remediation action

Scope the package's availability and deployment to a specific group instead of the whole tenant, or
work with the publisher to understand whether the flagged tool's destructive/open-world behavior is
expected before leaving it available by default.

#### Related links

- [Get Copilot package](https://learn.microsoft.com/graph/api/copilotadmin-get-package?view=graph-rest-1.0)

<!--- Results --->
%TestResult%
