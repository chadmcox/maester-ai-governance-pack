> [!NOTE]
> **Validated** 2026-11-05 against a real Microsoft 365 test tenant (F7-licensed; the package
> catalog API was reachable with `CopilotPackages.Read.All` alone). The run correctly **Failed**
> (true positive), finding 368 real custom/external packages available or deployed tenant-wide
> (for example "Lexis® Create DMS for Copilot", "Creately", "Dropbox"). The `publisher`,
> `availableTo`, and `deployedTo` field names and values matched the live schema; no additional
> Microsoft-publisher strings beyond the documented allowlist were observed in this tenant's data.

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
