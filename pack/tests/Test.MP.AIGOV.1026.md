> [!NOTE]
> **Not yet validated** against a live tenant. Ported from the alert rules in chadmcox/Copilot "Billing Health Check".

Checks that every enabled Copilot spending policy sends a budget alert to at least two active people.
Without a working alert, nobody hears about a policy nearing its limit until users are blocked.

| Severity | Condition |
| --- | --- |
| Medium | The policy has no email alert. |
| Medium | An alert recipient is disabled or no longer exists. |
| Low | The alert has only one recipient. |

#### Remediation action

Edit the policy in **Copilot > Cost management > Configuration**, turn on an email alert (80% is a good
starting threshold) and add at least two active owners as recipients. Replace recipients who have left.

#### Related links

- [Manage Copilot Credits spending policies](https://learn.microsoft.com/copilot/implement/usage-based-billing-manage-copilot-credits)
- [Cost management API overview](https://learn.microsoft.com/microsoft-365/copilot/extensibility/api/admin-settings/cost-management/overview)

<!--- Results --->
%TestResult%
