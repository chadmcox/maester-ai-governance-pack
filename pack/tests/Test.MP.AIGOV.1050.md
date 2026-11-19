Checks that only SharePoint admins can change Restricted Content Discovery and Restricted Access Control on sites.
Reads the SharePoint tenant settings through Maester's SharePoint connection (`Get-MtSpo`, which uses
`Get-PnPTenant`).

- **Restricted Content Discovery** keeps a site's content out of organization-wide search and Microsoft 365
  Copilot answers.
- **Restricted Access Control** limits a site to the groups you name.

Both are controls you set while you fix oversharing for Copilot. When
`DelegateRestrictedContentDiscoverabilityManagement` or `DelegateRestrictedAccessControlManagement` is `True`,
site admins and owners can turn them off on their own sites. Both default to `False`. PnP.PowerShell returns
them as `DelegateRestrictedContentDiscoveryConfiguration` and `DelegateRestrictedAccessControlConfiguration`;
the check reads either name.

- **Fail (Low):** either setting is `True`.
- **Not returned:** a setting your PnP.PowerShell version doesn't read is listed and doesn't fail.
- **Skip:** neither setting is returned.

This check doesn't look at which sites have the restrictions on. Microsoft's tenant-wide report for that is
`Start-SPORestrictedContentDiscoverabilityReport` in SharePoint Online PowerShell.

Frameworks: Microsoft Zero Trust for Copilot (oversharing controls); OWASP LLM02 (sensitive information
disclosure); NIST 800-53 AC-6.

> [!NOTE]
> **Settings confirmed Nov 19, 2026:** `Get-PnPTenant` returned both settings (`...Configuration` names, both
> `False`) on a test tenant. The full Maester run of this check is still pending.

#### Remediation action

Run this in SharePoint Online PowerShell as a SharePoint Administrator:

```powershell
Set-SPOTenant -DelegateRestrictedContentDiscoverabilityManagement $false
Set-SPOTenant -DelegateRestrictedAccessControlManagement $false
```

#### Related links

- [Restrict discovery of SharePoint sites and content](https://learn.microsoft.com/sharepoint/restricted-content-discovery)
- [Set-SPOTenant](https://learn.microsoft.com/powershell/module/microsoft.online.sharepoint.powershell/set-spotenant?view=sharepoint-ps)

<!--- Results --->
%TestResult%
