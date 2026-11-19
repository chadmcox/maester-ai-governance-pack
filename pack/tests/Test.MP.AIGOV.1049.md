Checks that agents can't share SharePoint and OneDrive content with people outside your organization. Reads the
SharePoint tenant settings through Maester's SharePoint connection (`Get-MtSpo`, which uses `Get-PnPTenant`).

- **Pass:** `RestrictExternalSharingForAgents` is `True`, or external sharing is off for the whole tenant
  (`SharingCapability` is `Disabled`).
- **Fail (Medium):** `RestrictExternalSharingForAgents` is `False` and external sharing is on.
- **Skip:** the setting isn't returned. Microsoft lists it as preview, and older PnP.PowerShell versions don't
  read new tenant settings.

An agent that can share externally can move data out of the tenant with one action. That's the exfiltration
path the OWASP agentic list calls tool misuse.

Frameworks: OWASP ASI02 (tool misuse) and ASI03 (identity and privilege abuse); MCSB v2 AI-4 (least privilege
for agent functions); NIST 800-53 AC-21.

> [!NOTE]
> **Setting confirmed Nov 19, 2026:** `Get-PnPTenant` returned `RestrictExternalSharingForAgents = False` with
> `SharingCapability = ExternalUserAndGuestSharing` on a test tenant, so this check should fail there. The full
> Maester run of this check is still pending. The setting is in preview.

#### Remediation action

Run this in SharePoint Online PowerShell as a SharePoint Administrator:

```powershell
Set-SPOTenant -RestrictExternalSharingForAgents $true
```

#### Related links

- [Set-SPOTenant (RestrictExternalSharingForAgents)](https://learn.microsoft.com/powershell/module/microsoft.online.sharepoint.powershell/set-spotenant?view=sharepoint-ps)

<!--- Results --->
%TestResult%
