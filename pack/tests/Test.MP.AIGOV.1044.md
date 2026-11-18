Checks how long Copilot and agent interaction audit records are kept. Reads `Get-UnifiedAuditLogRetentionPolicy`
(Security & Compliance PowerShell). A policy covers Copilot when its `RecordTypes` include `CopilotInteraction`
(Microsoft 365 Copilot, Copilot Chat, Cowork, Security Copilot and Copilot Studio agents) and it isn't narrowed by
`Operations` or `UserIds`.

Fails (Medium) when no policy covers `CopilotInteraction`, or the longest one is shorter than `MinimumRetention`
(default `TwelveMonths`, setting `AIGOV.MinimumAiAuditRetention`). Without a policy, Audit (Standard) keeps these
records for 180 days. Coverage of `ConnectedAIAppInteraction` is reported for information.

Needs Microsoft Purview Audit (Premium); ten-year retention needs the add-on license. `MT.1172` checks that the
unified audit log is on.

Framework: CISA draft SCuBA agent baseline MS.SI.5.1, 11.4; NIST 800-53 AU-11.

> [!NOTE]
> **Not yet validated** against a live tenant. Unit-tested only (Pester, mocked data). Run it against your
> tenant and check the result before relying on it.

#### Remediation action

Create an audit log retention policy for the `CopilotInteraction` record type with at least your required duration,
for example: `New-UnifiedAuditLogRetentionPolicy -Name 'Copilot interactions' -RecordTypes CopilotInteraction -RetentionDuration TwelveMonths -Priority 100`.

#### Related links

- [Audit logs for Copilot and AI applications](https://learn.microsoft.com/purview/audit-copilot)
- [Manage audit log retention policies](https://learn.microsoft.com/purview/audit-log-retention-policies)

<!--- Results --->
%TestResult%
