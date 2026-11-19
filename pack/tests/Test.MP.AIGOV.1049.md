An agent that can share content externally can send your organization's files outside with a single action, whether it was tricked by a prompt or misconfigured. Blocking external sharing for agents closes that path for data loss.

#### Remediation action

Run this in SharePoint Online PowerShell as a SharePoint Administrator:

```powershell
Set-SPOTenant -RestrictExternalSharingForAgents $true
```

#### Related links

- [Set-SPOTenant (RestrictExternalSharingForAgents)](https://learn.microsoft.com/powershell/module/microsoft.online.sharepoint.powershell/set-spotenant?view=sharepoint-ps)
- [How this check works](https://github.com/chadmcox/maester-ai-governance-pack/blob/main/docs/how-checks-work.md#mp-aigov-1049)

<!--- Results --->
%TestResult%
