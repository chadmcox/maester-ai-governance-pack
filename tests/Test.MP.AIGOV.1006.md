> [!WARNING]
> **NOT VALIDATED.** This test depends on the Copilot package catalog (Microsoft Agent 365 license).
> It has not been run end to end against an Agent 365-licensed test tenant. Confirm the live
> `displayName`/`description` field names and real-world placeholder patterns before relying on the
> result.

Checks whether an agent's display name or description is empty, or whether the display name matches
a placeholder pattern (test, demo, copy, draft, untitled, and similar). Without a clear name and
description, reviewers and users have nothing to judge the agent's purpose by.

#### Remediation action

Give the agent a clear, specific display name and a description of what it does and who it is for.

#### Related links

- [List Copilot packages](https://learn.microsoft.com/graph/api/copilotadmin-list-packages?view=graph-rest-1.0)

<!--- Results --->
%TestResult%
