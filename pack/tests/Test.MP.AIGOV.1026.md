> [!NOTE]
> **Validated** 2026-11-09 against a real Microsoft 365 test tenant, via an actual `Invoke-Maester` run.
> The run correctly **Failed** (true positive): all 8 enabled spending policies in this tenant have no
> email alert configured. Confirms `emailThresholdSettings` reads and types as expected (`isEnabled`,
> `threshold`). No enabled policy in this tenant has an alert turned on, so the recipient-disabled and
> single-recipient paths weren't exercised against real data this run.

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
