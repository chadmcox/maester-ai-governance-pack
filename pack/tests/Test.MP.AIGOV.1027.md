> [!NOTE]
> **Validated** 2026-11-09 against a real Microsoft 365 test tenant, via an actual `Invoke-Maester` run.
> The run correctly **Failed** (true positive): the group behind the "Cowork Limited" policy has a nested
> group. First live run surfaced a real bug: the beta `assignedGroups` navigation property under
> `selectedGroupsSpendingPolicy` returns HTTP 404 when `-Select` asks for a single field (`id` alone), even
> though the resource exists; asking for two or more fields (`id`, `displayName`) works. Fixed by widening
> `-Select`, with a regression unit test and the same fix applied to `MP.AIGOV.1032`.

Checks the groups linked to enabled Copilot spending policies. Microsoft documents security groups as the way
to put specific users in a spending policy.

| Severity | Condition |
| --- | --- |
| Medium | Microsoft 365 group, or not security-enabled. |
| Medium | Has nested groups. Microsoft doesn't document whether spending policies count nested members. |
| Low | Has no members. |
| Info | Dynamic group. Fine for broad audiences; for spend tiers, access packages give requested, reviewed membership. Info-only results pass. |

Owners and descriptions are `MP.AIGOV.1014`. A linked group that no longer exists is `MP.AIGOV.1025`.

#### Remediation action

Link a security group to the policy, add people to it directly rather than through nested groups, and
retire policies whose group is empty.

#### Related links

- [Add an identity-based spending policy](https://learn.microsoft.com/copilot/implement/usage-based-billing-manage-copilot-credits#add-identity-based-spending-policy)

<!--- Results --->
%TestResult%
