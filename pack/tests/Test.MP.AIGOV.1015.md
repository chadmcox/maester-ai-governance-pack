When policies overlap, the most permissive one wins. A lower per-user limit that a looser policy overrides gives a false sense of control: the cap you think applies does nothing for the people it overlaps with.

#### Remediation action

For each finding, decide which limit should apply to that audience. Then either remove the group from the
more permissive policy, lower that policy's per-user limit, or delete the policy whose cap has no effect.
Avoid combining an unlimited all-users policy with capped group policies: the caps won't apply.

#### Related links

- [Understand policy hierarchy](https://learn.microsoft.com/copilot/implement/usage-based-billing-manage-copilot-studio-costs#understand-policy-hierarchy)
- [List assignedGroups](https://learn.microsoft.com/microsoft-365/copilot/extensibility/api/admin-settings/cost-management/spendingpolicy-list-assignedgroups)
- [How this check works](https://github.com/chadmcox/maester-ai-governance-pack/blob/main/docs/how-checks-work.md#mp-aigov-1015)

<!--- Results --->
%TestResult%
