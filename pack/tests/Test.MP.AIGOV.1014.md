> [!NOTE]
> **Validated** 2026-11-06 against a real Microsoft 365 test tenant (F7-licensed), via an actual
> `Invoke-Maester` run. The run correctly **Failed** (true positive): all 8 distinct groups backing
> an enabled, group-scoped spending policy had zero owners, and several also had no `description`.
> Reading `assignedGroups` needs `CopilotCostManagement-Assignment.Read.All`; reading group owners and descriptions needs the
> standard `Group.Read.All` (or `Directory.Read.All`). Both are delegated-permission surfaces for
> this endpoint — Microsoft Learn lists Application permission type as not supported.

Checks whether a group backing a `selectedGroupsSpendingPolicy` has fewer than a configurable
minimum number of owners (default 2) or a blank `description`. Only groups assigned to a currently
`enabled` policy are evaluated. A spending-policy audience with no one accountable for its
membership, or no recorded reason for its existence, is itself a governance gap, independent of
anything about the policy's own settings — this complements MP.AIGOV.1013 and MP.AIGOV.1015, which
check the policy configuration rather than the audience that configuration applies to.

#### Remediation action

Add at least the configured minimum number of owners to the group, and give it a description that
explains why it exists and what spending policy depends on it.

#### Related links

- [List assignedGroups](https://learn.microsoft.com/microsoft-365/copilot/extensibility/api/admin-settings/cost-management/spendingpolicy-list-assignedgroups)

<!--- Results --->
%TestResult%
