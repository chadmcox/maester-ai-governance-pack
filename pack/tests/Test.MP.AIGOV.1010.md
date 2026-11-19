An agent sends user prompts and data to its MCP servers. A server on a domain you haven't reviewed is a third party getting your data and deciding what the agent does next. Keeping MCP servers on known hosts limits who your agents trust.

#### Remediation action

Review the MCP server's host and publisher. If it's a reviewed, approved vendor, add its host to
your `-AllowedHosts` list. If it isn't, investigate why the package was installed and consider
removing it until it has been reviewed.

#### Related links

- [Get Copilot package](https://learn.microsoft.com/graph/api/copilotadmin-get-package?view=graph-rest-1.0)
- [How this check works](https://github.com/chadmcox/maester-ai-governance-pack/blob/main/docs/how-checks-work.md#mp-aigov-1010)

<!--- Results --->
%TestResult%
