> [!NOTE]
> **Not yet validated** against a live tenant. Ported from the member rules in chadmcox/Copilot "Billing Health Check".

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
