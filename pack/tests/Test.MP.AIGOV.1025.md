A spending policy that isn't enabled, isn't scoped to a group, or points at a deleted group doesn't control what you think it does. Copilot credit spend can then go to the wrong people or have no limit at all.

#### Remediation action

In the Microsoft 365 admin center, go to **Copilot > Cost management > Configuration** and edit the policy:
scope it to a security group (**Identity > Specific groups**), link a group that exists, pick a billing
method, and set a per-user limit that fits how much people use. Recreate any policy whose status isn't
enabled after fixing its group.

#### Related links

- [Add an identity-based spending policy](https://learn.microsoft.com/copilot/implement/usage-based-billing-manage-copilot-credits#add-identity-based-spending-policy)
- [List spendingPolicies](https://learn.microsoft.com/microsoft-365/copilot/extensibility/api/admin-settings/cost-management/spendingpolicy-list)
- [How this check works](https://github.com/chadmcox/maester-ai-governance-pack/blob/main/docs/how-checks-work.md#mp-aigov-1025)

<!--- Results --->
%TestResult%
