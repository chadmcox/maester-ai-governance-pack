> [!NOTE]
> **Validated** 2026-11-06 against a real Microsoft 365 test tenant (F7-licensed), via an actual
> `Invoke-Maester` run (not just a manual query). The run correctly **Failed** (true positive): all 8
> currently-enabled Copilot spending policies had an unlimited `periodLimit`
> (`#microsoft.graph.unlimitedCostManagementQuantity`). This surface is reachable with
> `CopilotCostManagement-Policy.Read.All` alone and is delegated-permission only — Microsoft Learn
> lists Application permission type as not supported for this endpoint.

Checks whether an enabled Copilot spending policy has no overall credit ceiling. A policy's
`periodLimit` is an `@odata.type`-discriminated `costManagementQuantity`: either
`#microsoft.graph.limitedCostManagementQuantity` (a real numeric `value` cap) or
`#microsoft.graph.unlimitedCostManagementQuantity` (no cap at all). A `disabled` policy is not
currently in effect and is excluded. An unbounded policy has no ceiling to catch runaway
Copilot/agent consumption, regardless of how tightly its audience is scoped — the per-user limit
alone does not bound total tenant spend under that policy.

#### Remediation action

Set a numeric `periodLimit` on the policy, sized to the tenant's actual budget for that audience,
instead of leaving it unlimited.

#### Related links

- [List spendingPolicies](https://learn.microsoft.com/microsoft-365/copilot/extensibility/api/admin-settings/cost-management/spendingpolicy-list)

<!--- Results --->
%TestResult%
