> [!NOTE]
> **Validated** 2026-11-05 against a real Microsoft 365 test tenant (F7-licensed; the package
> catalog API was reachable with `CopilotPackages.Read.All` alone). The run correctly **Passed**:
> no blocked package had an open pending install or consent request. The `requestStatus`/
> `requestType` field names matched the live schema.

Checks whether a package the tenant has blocked (`isBlocked`) still has an open pending install or
consent request (`requestStatus`/`requestType`). A pending request against a blocked package means a
user can still be waiting on, or an admin can still approve, an install the tenant already decided to
block.

#### Remediation action

Cancel or deny the pending request for every blocked package found, and confirm with the requester
why they were still able to request an install that was already blocked.

#### Related links

- [List Copilot packages](https://learn.microsoft.com/graph/api/copilotadmin-list-packages?view=graph-rest-1.0)

<!--- Results --->
%TestResult%
