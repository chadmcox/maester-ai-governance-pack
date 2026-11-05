> [!WARNING]
> **NOT VALIDATED.** This test depends on the Copilot package catalog (Microsoft Agent 365 license),
> specifically the per-package detail call. It has not been run end to end against an Agent
> 365-licensed test tenant. Confirm the live `allowedUsersAndGroups`/`acquireUsersAndGroups` field
> names and `resourceType` values on the package detail response before relying on the result.

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
