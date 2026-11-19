Restricted Content Discovery and Restricted Access Control keep oversharing sites out of Copilot while you fix permissions. If site owners can turn them off, a single owner can undo the protection for their site.

#### Remediation action

Run this in SharePoint Online PowerShell as a SharePoint Administrator:

```powershell
Set-SPOTenant -DelegateRestrictedContentDiscoverabilityManagement $false
Set-SPOTenant -DelegateRestrictedAccessControlManagement $false
```

#### Related links

- [Restrict discovery of SharePoint sites and content](https://learn.microsoft.com/sharepoint/restricted-content-discovery)
- [Set-SPOTenant](https://learn.microsoft.com/powershell/module/microsoft.online.sharepoint.powershell/set-spotenant?view=sharepoint-ps)
- [How this check works](https://github.com/chadmcox/maester-ai-governance-pack/blob/main/docs/how-checks-work.md#mp-aigov-1050)

<!--- Results --->
%TestResult%
