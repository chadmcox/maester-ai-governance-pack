> [!NOTE]
> **Revised** 2026-11-06 to follow Microsoft's documented rule that the most permissive overlapping
> spending policy is enforced. The earlier version (validated 2026-11-06, true negative across 8
> enabled group-scoped policies) only flagged a group in two group-scoped policies and described the
> outcome as implementation-defined. **Re-validate against a live tenant before relying on this version.**

When more than one spending policy applies to a person, the most permissive one is enforced: the higher
limit applies, and limits from overlapping policies aren't added together. A lower per-user cap in an
overlapping policy therefore does nothing for the people it overlaps with.

This test reads every enabled spending policy. For each group in an enabled group-scoped policy, plus the
"All users" audience of any enabled all-users policy, it lists every policy that applies, works out the
effective per-user limit (Unlimited beats any cap; otherwise the highest cap wins) and reports:

| Severity | Condition |
| --- | --- |
| High | A policy's per-user cap is overridden by a policy with an unlimited per-user limit. |
| Medium | A policy's per-user cap is overridden by a policy with a higher per-user cap. |
| Low | Redundant overlap (two or more group-scoped policies with the same limit), or limits that can't be compared (missing, unreadable, or in different units). |

A group-scoped policy that is **more** permissive than an all-users base policy is the normal tiering
pattern (for example, everyone gets 100 credits and a pilot group gets 1,000) and is not reported.

Resource-scoped spending policies (Specific resource / Resource collection) aren't exposed by Graph yet,
so overlaps between a resource policy and an identity policy aren't evaluated. Resource policies take
precedence over identity policies for the agents and environments they cover; review them manually in the
Microsoft 365 admin center.

#### Remediation action

For each finding, decide which limit should apply to that audience. Then either remove the group from the
more permissive policy, lower that policy's per-user limit, or delete the policy whose cap has no effect.
Avoid combining an unlimited all-users policy with capped group policies: the caps won't apply.

#### Related links

- [Understand policy hierarchy](https://learn.microsoft.com/copilot/implement/usage-based-billing-manage-copilot-studio-costs#understand-policy-hierarchy)
- [List assignedGroups](https://learn.microsoft.com/microsoft-365/copilot/extensibility/api/admin-settings/cost-management/spendingpolicy-list-assignedgroups)

<!--- Results --->
%TestResult%
