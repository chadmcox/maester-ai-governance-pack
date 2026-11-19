Agents read tool descriptions to decide what to do. A description that gives the model instructions, such as to ignore earlier rules or hide actions from the user, can take over an agent without anyone noticing. Behavior annotations also tell admins what a tool can do.

#### Remediation action

Read the flagged tool's full definition. Block the package if the text tries to steer the model. For tools with
no annotations, ask the vendor to add them before you allow the package tenant-wide.

#### Related links

- [Get a Copilot package](https://learn.microsoft.com/graph/api/copilotadmin-get-package?view=graph-rest-1.0)
- [How this check works](https://github.com/chadmcox/maester-ai-governance-pack/blob/main/docs/how-checks-work.md#mp-aigov-1039)

<!--- Results --->
%TestResult%
