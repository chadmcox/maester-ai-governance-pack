> [!WARNING]
> **NOT VALIDATED.** This test depends on the Copilot package catalog (Microsoft Agent 365 license).
> It has not been run end to end against an Agent 365-licensed test tenant. Confirm the live
> `publisher`, `availableTo`, and `deployedTo` field names and values — and the full set of real
> publisher strings in use — before relying on the result.

Checks whether a custom or external (non-Microsoft-published) package is available or deployed
tenant-wide (`availableTo` indicating `allowedForAll`, or `deployedTo` indicating `acquiredForAll`).
A package is treated as Microsoft-published only when its `publisher` value is exactly one of:
`Microsoft Corporation`, `Microsoft`, `Microsoft 365`, or `Microsoft Copilot Studio`. Any other
value — including a blank or null one — counts as custom/external. A custom or external agent going
out to the whole tenant by default skips the deliberate, scoped rollout that kind of agent should get.

#### Remediation action

Scope the package's availability and deployment to a specific group instead of the whole tenant, and
confirm the rollout plan with the agent's sponsor before widening it again.

#### Related links

- [List Copilot packages](https://learn.microsoft.com/graph/api/copilotadmin-list-packages?view=graph-rest-1.0)

<!--- Results --->
%TestResult%
