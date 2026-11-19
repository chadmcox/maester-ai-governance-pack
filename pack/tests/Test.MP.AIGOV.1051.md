People share sites and files with agents to get help, often without thinking about what the agent can then read and act on. A disclaimer makes them stop and think before they give an agent access to content.

#### Remediation action

Run this in SharePoint Online PowerShell as a SharePoint Administrator:

```powershell
Set-SPOTenant -EnableAgentWorkerSharingDisclaimer $true
```

#### Related links

- [Set-SPOTenant (EnableAgentWorkerSharingDisclaimer)](https://learn.microsoft.com/powershell/module/microsoft.online.sharepoint.powershell/set-spotenant?view=sharepoint-ps)
- [How this check works](https://github.com/chadmcox/maester-ai-governance-pack/blob/main/docs/how-checks-work.md#mp-aigov-1051)

<!--- Results --->
%TestResult%
