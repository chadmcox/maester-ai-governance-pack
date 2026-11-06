function Test-MPAIGOV1019 {
    <#
    .SYNOPSIS
    Finds agent identities with user-consented (non-admin) delegated Graph permissions.
    .DESCRIPTION
    Lists agent identities via GET /servicePrincipals/microsoft.graph.agentIdentity (v1.0), then for
    each one calls GET /oauth2PermissionGrants?$filter=clientId eq '{agent identity object ID}' and
    consentType eq 'Principal' (v1.0) -- clientId is the service principal's object ID, not its
    appId, and $filter on this endpoint only supports eq, confirmed against the oauth2PermissionGrant
    resource and "List oauth2PermissionGrants" Learn reference pages. consentType 'Principal' means a
    single end user consented for themselves, as opposed to 'AllPrincipals' (an administrator
    consented tenant-wide) -- this test only reports the user-consented case, since an
    admin-consented grant is a deliberate, reviewed decision rather than an individual user's choice
    to grant an autonomous agent delegated access to their own data. Uses the least-privileged Graph
    permission confirmed on the "List oauth2PermissionGrants" reference page, Directory.Read.All
    (application).

    Findings are grouped per agent: number of distinct consenting users and the deduplicated set of
    granted scopes. An agent is Medium by default; High if any granted scope appears on Maester's own
    MT.1223 (Test-MtEntraAgentHighRiskGraphPermissions) high-risk permission list -- read directly
    from that test's source (Get-MtEntraAgentHighRiskGraphPermissionFinding.ps1, pinned commit
    616559854634e5150dbde69850c4224191635bb1, the same commit this pack's Test-MtPack CI job builds
    Maester from) rather than re-derived from memory, so it tracks Maester's actual classification
    instead of this pack's own guess at what counts as high risk. Maester's $RiskPaths hashtable
    isn't exported from the module, so it's reproduced here verbatim with that citation; keep this
    list in sync if MT.1223's source changes.
    .EXAMPLE
    Test-MPAIGOV1019
    .LINK
    https://learn.microsoft.com/graph/api/oauth2permissiongrant-list?view=graph-rest-1.0
    .LINK
    https://github.com/maester365/maester/blob/616559854634e5150dbde69850c4224191635bb1/powershell/internal/services/entra/Get-MtEntraAgentHighRiskGraphPermissionFinding.ps1
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1019',
        Title        = 'Agent identity should not have user-consented delegated permissions',
        Product      = 'entra',
        Feature      = 'agent-identities',
        Area         = 'ai',
        ResourceType = 'Agent',
        Severity     = 'Medium',
        Control      = 'nist-800-53-r5:AC-6',
        Permission   = 'Graph:Application:Directory.Read.All',
        Service      = 'Graph',
        Lifecycle    = 'Preview',
        LongRunning
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Reproduced verbatim from Maester's MT.1223 source (Get-MtEntraAgentHighRiskGraphPermissionFinding.ps1,
    # pinned commit 616559854634e5150dbde69850c4224191635bb1) -- see .LINK above. Not hand-derived.
    $HighRiskScopes = @(
        'AdministrativeUnit.ReadWrite.All',
        'Application.ReadUpdate.All',
        'DeviceManagementConfiguration.ReadWrite.All',
        'DeviceManagementRBAC.ReadWrite.All',
        'Policy.ReadWrite.ConditionalAccess',
        'PrivilegedAccess.ReadWrite.AzureADGroup',
        'PrivilegedAssignmentSchedule.ReadWrite.AzureADGroup',
        'PrivilegedEligibilitySchedule.ReadWrite.AzureADGroup',
        'RoleAssignmentSchedule.ReadWrite.Directory',
        'RoleEligibilitySchedule.ReadWrite.Directory',
        'RoleManagementPolicy.ReadWrite.AzureADGroup',
        'RoleManagementPolicy.ReadWrite.Directory'
    )

    try {
        Write-Verbose 'Reading agent identities.'
        $AgentIdentities = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri 'servicePrincipals/microsoft.graph.agentIdentity' `
                -Select @('id', 'displayName', 'appId')
        )
    } catch {
        $ErrorRecord = $_
    }
    if ($ErrorRecord) {
        if ($ErrorRecord.Exception.Message -match '(?i)403|forbidden|authorization') {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized -Result (
                "Couldn't read agent identities (403). Confirm the Directory.Read.All permission " +
                'before re-running this check.'
            )
        } else {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $ErrorRecord
        }
        return $null
    }

    if ($AgentIdentities.Count -eq 0) {
        Add-MtTestResultDetail -Result 'Well done. No agent identities were found in the tenant.'
        return $true
    }
    Write-Verbose "Found $($AgentIdentities.Count) agent identity(ies)."

    $Findings = [System.Collections.Generic.List[pscustomobject]]::new()
    $FailedAgentCount = 0
    foreach ($Agent in $AgentIdentities) {
        $AgentId = [string]$Agent.id
        if ([string]::IsNullOrWhiteSpace($AgentId)) { continue }

        try {
            $Grants = @(
                Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri 'oauth2PermissionGrants' `
                    -Filter "clientId eq '$AgentId' and consentType eq 'Principal'" `
                    -Select @('principalId', 'scope')
            )
        } catch {
            Write-Verbose "Skipping agent identity $AgentId after a grant-read error: $($_.Exception.Message)"
            $FailedAgentCount++
            continue
        }
        if ($Grants.Count -eq 0) { continue }

        $ConsentingUsers = [System.Collections.Generic.HashSet[string]]::new()
        $ScopeSet = [System.Collections.Generic.HashSet[string]]::new()
        foreach ($Grant in $Grants) {
            if (-not [string]::IsNullOrWhiteSpace([string]$Grant.principalId)) {
                [void]$ConsentingUsers.Add([string]$Grant.principalId)
            }
            foreach ($Scope in (@([string]$Grant.scope -split '\s+') | Where-Object { $_ })) {
                [void]$ScopeSet.Add($Scope)
            }
        }
        if ($ScopeSet.Count -eq 0) { continue }

        $HighRiskScopesFound = @($ScopeSet | Where-Object { $HighRiskScopes -contains $_ })

        $Findings.Add([pscustomobject]@{
            AgentId              = $AgentId
            DisplayName          = [string]$Agent.displayName
            ConsentingUsersCount = $ConsentingUsers.Count
            Scopes               = (($ScopeSet | Sort-Object) -join ', ')
            HighRiskScopes       = (($HighRiskScopesFound | Sort-Object) -join ', ')
            Severity             = if ($HighRiskScopesFound.Count -gt 0) { 'High' } else { 'Medium' }
        })
    }

    if ($Findings.Count -eq 0) {
        $Result = 'Well done. No agent identity has a user-consented (non-admin) delegated permission ' +
            "($($AgentIdentities.Count) agent identity(ies) checked)."
        if ($FailedAgentCount -gt 0) {
            $Result += "`n`n$FailedAgentCount agent identity(ies) could not be evaluated (grant-read error) " +
                'and are not reflected in this result.'
        }
        Add-MtTestResultDetail -Result $Result
        return $true
    }

    $HighestSeverity = if ($Findings.Severity -contains 'High') { 'High' } else { 'Medium' }

    $Result = "Found $($Findings.Count) agent identity(ies) with user-consented (non-admin) delegated permissions."
    if ($FailedAgentCount -gt 0) {
        $Result += " $FailedAgentCount agent identity(ies) could not be evaluated (grant-read error) " +
            'and are not reflected below.'
    }
    $Result += "`n`n| Agent object ID | Display name | Consenting users | Scopes | High-risk scope(s) | Severity |"
    $Result += "`n| --- | --- | --- | --- | --- | --- |"
    foreach ($Item in $Findings) {
        $Name = [string]$Item.DisplayName
        if ([string]::IsNullOrWhiteSpace($Name)) { $Name = '(unnamed)' }
        $Name = [System.Net.WebUtility]::HtmlEncode($Name) -replace '\|', '&#124;'
        $Name = $Name -replace "`r?`n", ' '
        $Scopes = [System.Net.WebUtility]::HtmlEncode($Item.Scopes) -replace '\|', '&#124;'
        $HighRiskScopesText = if ([string]::IsNullOrWhiteSpace($Item.HighRiskScopes)) { '-' } else {
            [System.Net.WebUtility]::HtmlEncode($Item.HighRiskScopes) -replace '\|', '&#124;'
        }
        $Result += "`n| $($Item.AgentId) | $Name | $($Item.ConsentingUsersCount) | $Scopes | " +
            "$HighRiskScopesText | $($Item.Severity) |"
    }

    Add-MtTestResultDetail -Result $Result -Severity $HighestSeverity
    return $false
}
