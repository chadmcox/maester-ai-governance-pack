> [!NOTE]
> **Validated** 2026-11-09 against a real Microsoft 365 test tenant, via an actual `Invoke-Maester` run.
> The run correctly **Failed** (true positive): 4 of 5 spending-policy group members were flagged
> (disabled account, guest account, missing Copilot license, stale sign-in). Confirms `serviceSettings`,
> `transitiveMembers/microsoft.graph.user` (with `assignedLicenses` and `licenseAssignmentStates`), and
> batched `users -UniqueId -Select @('id','signInActivity')` all read and type as expected; no 404 occurred
> inside that batch for the 5 real member IDs checked. First live run surfaced a real bug: the beta
> `assignedGroups` navigation property under `selectedGroupsSpendingPolicy` 404s when `-Select` asks for a
> single field (`id` alone); asking for two or more fields works. Fixed by widening `-Select`, with a
> regression unit test (same fix applied to `MP.AIGOV.1027`).

Checks the people in groups linked to enabled Copilot spending policies (including members of nested groups).
Each one reported is Medium:

- The account is disabled.
- The account is a guest.
- No successful sign-in for `InactiveDays` (default 90). This needs `signInActivity` (AuditLog.Read.All and
  Microsoft Entra ID P1). If it can't be read, the check is skipped and the result says so.
- No working Microsoft 365 Copilot license, when the policy turns on a service that needs one
  (`LicensedServices`, default `cowork` and `code`). Working means the license's SKU includes a Copilot service
  plan, that plan isn't disabled, and the assignment isn't in an error state.

All-users policies aren't checked here; `MP.AIGOV.1025` reports them. At most `MaxMembers` (default 5,000)
unique members are checked per run, and the table shows the first 100.

#### Remediation action

Remove disabled, guest and inactive people from the policy's group, unless guests are meant to spend
credits. Assign a working Copilot license to anyone who should use a licensed service, or remove them.

#### Related links

- [Manage Copilot Credits spending policies](https://learn.microsoft.com/copilot/implement/usage-based-billing-manage-copilot-credits)
- [signInActivity resource type](https://learn.microsoft.com/graph/api/resources/signinactivity)

<!--- Results --->
%TestResult%
