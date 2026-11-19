An MCP server can change a tool after you approve it, so the tool does something different from what you reviewed. Comparing tools with an approved baseline catches these silent changes before an agent uses the new behavior.

#### Remediation action

Review each changed or new tool's definition. If you accept it, update its fingerprint in the baseline. If you
don't, block the package in the Microsoft 365 admin center until the vendor explains the change.

#### Related links

- [Get a Copilot package](https://learn.microsoft.com/graph/api/copilotadmin-get-package?view=graph-rest-1.0)
- [How this check works](https://github.com/chadmcox/maester-ai-governance-pack/blob/main/docs/how-checks-work.md#mp-aigov-1038)

<!--- Results --->
%TestResult%
