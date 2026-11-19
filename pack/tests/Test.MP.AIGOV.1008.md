An MCP server reached over plain HTTP sends agent requests, tool results and any tokens unencrypted. Anyone on the network path can read or change what the agent sends and receives, which can leak data or feed the agent false results.

#### Remediation action

Contact the MCP server operator (or the package publisher) and request an `https://` endpoint, or
remove the package until one is available.

#### Related links

- [Get Copilot package](https://learn.microsoft.com/graph/api/copilotadmin-get-package?view=graph-rest-1.0)
- [How this check works](https://github.com/chadmcox/maester-ai-governance-pack/blob/main/docs/how-checks-work.md#mp-aigov-1008)

<!--- Results --->
%TestResult%
