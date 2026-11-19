When a user consents to permissions for an agent, the agent acts with that user's access without an admin reviewing it. Admin consent keeps the decision about what agents can reach with the people responsible for your data.

#### Remediation action

Review each listed scope with the consenting user(s). If the access isn't intentional or necessary,
revoke the grant. If any High-risk scope is present, treat it with the same urgency as `MT.1223`'s
application-permission findings.

#### Related links

- [List oauth2PermissionGrants (delegated permission grants)](https://learn.microsoft.com/graph/api/oauth2permissiongrant-list?view=graph-rest-1.0)
- [Get-MtEntraAgentHighRiskGraphPermissionFinding.ps1 (Maester source, pinned commit)](https://github.com/maester365/maester/blob/616559854634e5150dbde69850c4224191635bb1/powershell/internal/services/entra/Get-MtEntraAgentHighRiskGraphPermissionFinding.ps1)
- [How this check works](https://github.com/chadmcox/maester-ai-governance-pack/blob/main/docs/how-checks-work.md#mp-aigov-1019)

<!--- Results --->
%TestResult%
