> [!NOTE]
> **Validated** 2026-11-06 against a real Microsoft 365 test tenant (F7-licensed), via an actual
> `Invoke-Maester` run. The run correctly **Passed** (true negative): across 8 enabled, group-scoped
> spending policies, no group backed more than one of them. This is a well-formed negative, not
> evidence the overlap condition can't occur — a tenant can legitimately reuse a group across
> multiple policies, which this test would then flag.

Checks whether a group is assigned to more than one enabled, group-scoped Copilot spending policy at
once. With two enabled policies targeting the same audience, whichever applies first is
implementation-defined, and the two caps — if they differ — are not a single reviewable ceiling for
that group. This is a distinct condition from `MP.AIGOV.1004`'s declarative-agent connector reuse
check: this one looks at Copilot spending-policy group assignment, not agent-to-connector mapping.

A Graph schema review for this work also confirmed there is no per-user, non-group spending-policy
assignment type in the beta `spendingPolicy` hierarchy (only `allUsersSpendingPolicy` and
`selectedGroupsSpendingPolicy` exist) — so a check for a user being assigned directly to a policy,
bypassing group membership, is not a buildable Graph-API condition and is intentionally not covered
by any MP.AIGOV test.

#### Remediation action

Reassign the group to a single spending policy, or confirm that the overlap is intentional and that
the resulting effective cap for that group is understood and acceptable.

#### Related links

- [List assignedGroups](https://learn.microsoft.com/microsoft-365/copilot/extensibility/api/admin-settings/cost-management/spendingpolicy-list-assignedgroups)

<!--- Results --->
%TestResult%
