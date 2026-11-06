Lists agent identities via `GET /servicePrincipals/microsoft.graph.agentIdentity` (v1.0), then for
each one calls `GET /oauth2PermissionGrants?$filter=clientId eq '{agent identity object ID}' and
consentType eq 'Principal'` (v1.0) — `clientId` is the service principal's object ID, not its
`appId`, and `$filter` on this endpoint only supports `eq`, confirmed against the
`oauth2PermissionGrant` resource and "List oauth2PermissionGrants" Learn reference pages.
`consentType` `Principal` means a single end user consented for themselves, as opposed to
`AllPrincipals` (an administrator consented tenant-wide) — this test only reports the
user-consented case, since an admin-consented grant is a deliberate, reviewed decision rather than
an individual user's choice to grant an autonomous agent delegated access to their own data. Uses
the least-privileged Graph permission confirmed on the "List oauth2PermissionGrants" reference page,
`Directory.Read.All` (application).

Findings are grouped per agent identity: the number of distinct consenting users and the
deduplicated set of granted scopes. An agent is **Medium** by default; **High** if any granted scope
appears on Maester's own `MT.1223` (`Test-MtEntraAgentHighRiskGraphPermissions`) high-risk
permission list. That list was read directly from `MT.1223`'s source
(`Get-MtEntraAgentHighRiskGraphPermissionFinding.ps1`, pinned commit
`616559854634e5150dbde69850c4224191635bb1` — the same commit this pack's `Test-MtPack` CI job builds
Maester from) rather than re-derived from memory, so it tracks Maester's actual classification
instead of a separate guess at what counts as high risk. That hashtable isn't exported from the
module, so it is reproduced here verbatim with this citation; keep it in sync if `MT.1223`'s source
changes.

> [!NOTE]
> **Validated** 2026-11-06 against a real Microsoft 365 test tenant (F7-licensed). The run
> correctly **Passed** (true negative): 11 agent identities were checked and none had a
> user-consented (non-admin) delegated permission grant, so the High-severity path (a scope on
> MT.1223's high-risk list) was not exercised against real data this round.

#### Remediation action

Review each listed scope with the consenting user(s). If the access isn't intentional or necessary,
revoke the grant. If any High-risk scope is present, treat it with the same urgency as `MT.1223`'s
application-permission findings.

#### Related links

- [List oauth2PermissionGrants (delegated permission grants)](https://learn.microsoft.com/graph/api/oauth2permissiongrant-list?view=graph-rest-1.0)
- [Get-MtEntraAgentHighRiskGraphPermissionFinding.ps1 (Maester source, pinned commit)](https://github.com/maester365/maester/blob/616559854634e5150dbde69850c4224191635bb1/powershell/internal/services/entra/Get-MtEntraAgentHighRiskGraphPermissionFinding.ps1)

<!--- Results --->
%TestResult%
