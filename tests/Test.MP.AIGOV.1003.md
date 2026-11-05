> [!NOTE]
> **Validated** 2026-11-05 against a real Microsoft 365 test tenant (F7-licensed; the package
> catalog API was reachable with `CopilotPackages.Read.All` alone). The run correctly **Failed**
> (true positive), finding 1 real package ("Copilot Code") with a directly assigned user. The
> per-package detail call's `allowedUsersAndGroups`/`acquireUsersAndGroups` field names and
> `resourceType` values matched the live schema. This test is slow (iterates every package's detail
> individually) — expect several minutes against a catalog with hundreds of packages.

Checks whether an agent is assigned directly to individual users instead of through a group. The
audience collections (`allowedUsersAndGroups`, `acquireUsersAndGroups`) are only returned by the
per-package detail call (`GET /copilot/admin/catalog/packages/{id}`) — the list call does not return
them, so this test reads every package's detail individually. A direct user assignment has no group
to audit membership through and no single place to see who has access.

#### Remediation action

Create or reuse a group for each agent's intended audience, add the directly assigned users to it,
assign the agent to the group, and remove the direct user assignments.

#### Related links

- [Get Copilot package](https://learn.microsoft.com/graph/api/copilotadmin-get-package?view=graph-rest-1.0)

<!--- Results --->
%TestResult%
