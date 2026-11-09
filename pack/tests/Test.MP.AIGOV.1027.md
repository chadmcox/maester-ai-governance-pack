> [!NOTE]
> **Not yet validated** against a live tenant. Ported from the group rules in chadmcox/Copilot "Billing Health Check".

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
