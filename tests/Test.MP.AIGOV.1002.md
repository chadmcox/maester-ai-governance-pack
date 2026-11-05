> [!WARNING]
> **NOT VALIDATED.** This test depends on the Copilot package catalog (Microsoft Agent 365 license).
> It has not been run end to end against an Agent 365-licensed test tenant. Confirm the live
> `requestStatus`/`requestType` field names and values before relying on the result.

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
