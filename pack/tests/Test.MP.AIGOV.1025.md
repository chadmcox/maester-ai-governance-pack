> [!NOTE]
> **Validated** 2026-11-09 against a real Microsoft 365 test tenant, via an actual `Invoke-Maester` run.
> The run correctly **Failed** (true positive): 10 problems across 3 group-scoped "Test Cowork ..."
> policies (disabled status, no group linked, billing method not set, a per-user limit below the default
> 2,000-credit threshold). No `allUsersSpendingPolicy` exists in this tenant yet, so the "scope All users"
> High-severity path wasn't exercised against real data this run.

Checks that every Copilot spending policy is scoped to an existing security group and fully configured.

| Severity | Condition |
| --- | --- |
| High | The policy covers all users instead of a security group. |
| High | The policy's status isn't `enabled`. |
| High | A group-scoped policy has no group linked. |
| High | A group linked to the policy no longer exists. |
| Medium | The billing method isn't set. |
| Medium | The per-user limit is a cap below `MinPerUserCredits` (default 2,000). |

A policy with no overall ceiling is `MP.AIGOV.1013`; group owners and descriptions are `MP.AIGOV.1014`;
overlapping policies are `MP.AIGOV.1015`.

#### Remediation action

In the Microsoft 365 admin center, go to **Copilot > Cost management > Configuration** and edit the policy:
scope it to a security group (**Identity > Specific groups**), link a group that exists, pick a billing
method, and set a per-user limit that fits how much people use. Recreate any policy whose status isn't
enabled after fixing its group.

#### Related links

- [Add an identity-based spending policy](https://learn.microsoft.com/copilot/implement/usage-based-billing-manage-copilot-credits#add-identity-based-spending-policy)
- [List spendingPolicies](https://learn.microsoft.com/microsoft-365/copilot/extensibility/api/admin-settings/cost-management/spendingpolicy-list)

<!--- Results --->
%TestResult%
