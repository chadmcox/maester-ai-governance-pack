> [!NOTE]
> **Validated** 2026-11-05 against a real Microsoft 365 test tenant (F7-licensed; the package
> catalog API was reachable with `CopilotPackages.Read.All` alone). The initial run against the live
> schema **errored**: `description` is not a valid property on `microsoft.graph.copilotPackageDetail`
> (Graph returned HTTP 400). The real fields are `shortDescription` and `longDescription`. The test
> was fixed to select and check both fields (empty counts only if both are blank), then re-run and
> correctly **Failed** (true positive), finding 3 real packages with an empty description.

Checks whether an agent's display name or description is empty, or whether the display name matches
a placeholder pattern (test, demo, copy, draft, untitled, and similar). Without a clear name and
description, reviewers and users have nothing to judge the agent's purpose by.

#### Remediation action

Give the agent a clear, specific display name and a description of what it does and who it is for.

#### Related links

- [List Copilot packages](https://learn.microsoft.com/graph/api/copilotadmin-list-packages?view=graph-rest-1.0)

<!--- Results --->
%TestResult%
