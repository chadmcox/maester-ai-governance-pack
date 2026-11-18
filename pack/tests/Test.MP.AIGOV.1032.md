> [!NOTE]
> **Validated** Nov 18, 2026 against a real Microsoft 365 test tenant. The corrected run **Failed**
> (true positive): 30 of 5,000 evaluated members were flagged, comprising 23 stale successful sign-ins
> and seven older accounts with no recorded history. Independent reads confirmed all 30 findings.
> Of 4,976 null-history records, 4,969 were new accounts, too early to judge; none had unknown age.
> Five direct new-account reads retained null history. A tenant-wide stale-history query returned 49
> users, with no overlap among the null-history IDs. All seven older null-history accounts also retained
> null history on direct reads and were created after April 2020. Seeded origin was not established.
> The report identified 6,459 memberships beyond `MaxMembers` as unchecked; this is capped coverage,
> not proof of all tenant members. That count was memberships, not people; it now counts unique members
> and leads the result with the coverage percentage. No last-attempt fallback case was present live; unit tests cover it.
> Earlier per-user sign-in reads throttled or skipped; filtered collections now return all 5,000 records,
> including `createdDateTime`. The old null-object omission and premature empty-history findings were
> corrected with account-age checks, explicit summary counts and a last-attempt fallback.

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
- No successful sign-in for `InactiveDays` (default 90). When successful history is absent, use the later
  interactive or non-interactive attempt. Attempt timestamps include unsuccessful attempts and are not
  proof of successful use; successful history was not backfilled before December 1, 2023.
  If all history is blank, flag `No sign-in recorded` only when `createdDateTime` is older than the window.
  New accounts are counted as `new accounts, too early to judge`; missing age or unreadable history is
  counted as unknown, not silently treated as active. The summary includes these counts, fallback usage
  and stale activity. This needs `signInActivity` (AuditLog.Read.All and Microsoft Entra ID P1).
  If it can't be read, the check is skipped and the result says so.
- No working Microsoft 365 Copilot license, when the policy turns on a service that needs one
  (`LicensedServices`, default `cowork` and `code`). Working means the license's SKU includes a Copilot service
  plan, that plan isn't disabled, and the assignment isn't in an error state.

All-users policies aren't checked here; `MP.AIGOV.1025` reports them. At most `AIGOV.MaxSpendingPolicyMembers`
(default 5,000; `0` means no cap) unique members are checked per run, and the table shows the first 100. When
members go past the cap, the result starts with the coverage, for example "Partial coverage: checked 5000 of
11459 unique member(s) (43%)". A user in several groups counts once. A run with no findings but partial coverage
skips instead of passing, because the unchecked members could have problems. Raise the setting or set it to `0`
to check everyone; expect about one sign-in read per 15 members.
Sign-in reads use filtered collections of at most 15 IDs, with paging handled by Maester, rather than a
separate sign-in request for every member.

#### Remediation action

Remove disabled, guest and inactive people from the policy's group, unless guests are meant to spend
credits. Assign a working Copilot license to anyone who should use a licensed service, or remove them.

#### Related links

- [Manage Copilot Credits spending policies](https://learn.microsoft.com/copilot/implement/usage-based-billing-manage-copilot-credits)
- [signInActivity resource type](https://learn.microsoft.com/graph/api/resources/signinactivity)
- [Manage inactive user accounts](https://learn.microsoft.com/entra/identity/monitoring-health/howto-manage-inactive-user-accounts)

<!--- Results --->
%TestResult%
