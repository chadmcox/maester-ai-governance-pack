Copilot and agent interaction records are your evidence for investigations, eDiscovery and compliance. If they're kept for only the default 180 days, you can lose what you need before you know you need it.

#### Remediation action

Create an audit log retention policy for the `CopilotInteraction` record type with at least your required duration,
for example: `New-UnifiedAuditLogRetentionPolicy -Name 'Copilot interactions' -RecordTypes CopilotInteraction -RetentionDuration TwelveMonths -Priority 100`.

#### Related links

- [Audit logs for Copilot and AI applications](https://learn.microsoft.com/purview/audit-copilot)
- [Manage audit log retention policies](https://learn.microsoft.com/purview/audit-log-retention-policies)
- [How this check works](https://github.com/chadmcox/maester-ai-governance-pack/blob/main/docs/how-checks-work.md#mp-aigov-1044)

<!--- Results --->
%TestResult%
