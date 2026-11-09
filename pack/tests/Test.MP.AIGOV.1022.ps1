function Test-MPAIGOV1022 {
    <#
    .SYNOPSIS
    Finds agent identities and blueprint principals with broad Microsoft Graph permissions that MT.1223 doesn't cover.
    .DESCRIPTION
    Maester's MT.1223 flags agent identities holding the twelve Graph permissions on its privilege-
    escalation list. Broad permissions outside that list (Directory.ReadWrite.All, Mail.Send,
    Sites.FullControl.All, Files.ReadWrite.All and so on) aren't reported by it. This test applies the
    permission rules from chadmcox/Copilot "Agent and Tools Health Check" to the rest:
      - High:   a high-privilege permission (that repo's list: Directory, RoleManagement, Application,
                AppRoleAssignment, Policy, User, Group, GroupMember, Domain, Organization ReadWrite permissions,
                plus Mail.Send, Mail.ReadWrite, Sites.FullControl.All, Sites.ReadWrite.All,
                Files.ReadWrite.All, Directory.AccessAsUser.All and full_access_as_app).
      - Medium: any other tenant-wide write permission (*.ReadWrite.All).
    Reads application permissions (appRoleAssignments, plus inherited ones for agent identities) and
    admin-consented delegated grants (consentType AllPrincipals) on Microsoft Graph, for agent identities and
    agent identity blueprint principals. User-consented grants are MP.AIGOV.1019. Permissions on MT.1223's
    list are skipped so the same permission isn't reported twice.
    .EXAMPLE
    Test-MPAIGOV1022
    .LINK
    https://learn.microsoft.com/graph/permissions-reference
    .LINK
    https://github.com/maester365/maester/blob/616559854634e5150dbde69850c4224191635bb1/powershell/internal/services/entra/Get-MtEntraAgentHighRiskGraphPermissionFinding.ps1
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1022',
        Title        = 'Agent identity should not hold broad Microsoft Graph write permissions',
        Product      = 'entra',
        Feature      = 'agent-identities',
        Area         = 'ai',
        ResourceType = 'ServicePrincipal',
        Severity     = 'High',
        Permission   = 'Graph:Application:Application.Read.All|Graph:Application:Directory.Read.All',
        Service      = 'Graph',
        Lifecycle    = 'Preview'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # MT.1223's $RiskPaths keys (pinned Maester commit 6165598). Same list as MP.AIGOV.1019; a unit test
    # keeps the two in step. Permissions here are left to MT.1223.
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
    $HighPrivilegePattern = '^(Directory|RoleManagement|Application|AppRoleAssignment|Policy|User|Group|GroupMember|Domain|Organization)\.ReadWrite|^(Mail\.Send|Mail\.ReadWrite|Sites\.FullControl\.All|Sites\.ReadWrite\.All|Files\.ReadWrite\.All|Directory\.AccessAsUser\.All|full_access_as_app)$'

    try {
        Write-Verbose 'Reading agent identities, blueprint principals and the Microsoft Graph service principal.'
        $Principals = @(
            @(Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri 'servicePrincipals/microsoft.graph.agentIdentity' -Select @('id', 'displayName', 'appId')) |
                Where-Object { $_ } | ForEach-Object { [pscustomobject]@{ Id = [string]$_.id; Name = [string]$_.displayName; Kind = 'Agent identity' } }
            @(Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri 'servicePrincipals/microsoft.graph.agentIdentityBlueprintPrincipal' -Select @('id', 'displayName', 'appId')) |
                Where-Object { $_ } | ForEach-Object { [pscustomobject]@{ Id = [string]$_.id; Name = [string]$_.displayName; Kind = 'Blueprint principal' } }
        )
        $GraphSps = @(Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri 'servicePrincipals' `
                -Filter "appId eq '00000003-0000-0000-c000-000000000000'" -Select @('id', 'appRoles'))
        if ($GraphSps.Count -ne 1) { throw "Expected one Microsoft Graph service principal, found $($GraphSps.Count)." }
    } catch {
        $ErrorRecord = $_
    }
    if ($ErrorRecord) {
        if ($ErrorRecord.Exception.Message -match '(?i)403|forbidden|authorization') {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
        } else {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $ErrorRecord
        }
        return $null
    }

    $Principals = @($Principals | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Id) })
    if ($Principals.Count -eq 0) {
        Add-MtTestResultDetail -Result 'Well done. There are no agent identities or blueprint principals in the tenant.'
        return $true
    }

    $GraphSpId = [string]$GraphSps[0].id
    $RoleNames = @{}
    foreach ($Role in @($GraphSps[0].appRoles)) { if ($Role.id) { $RoleNames[[string]$Role.id] = [string]$Role.value } }

    $Findings = [System.Collections.Generic.List[pscustomobject]]::new()
    $Unread = [System.Collections.Generic.List[string]]::new()
    foreach ($Principal in $Principals) {
        $Permissions = [System.Collections.Generic.List[pscustomobject]]::new()
        try {
            $Assignments = @(Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri "servicePrincipals/$($Principal.Id)/appRoleAssignments" -Select @('appRoleId', 'resourceId'))
            $Grants = @(Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri "servicePrincipals/$($Principal.Id)/oauth2PermissionGrants" -Select @('resourceId', 'scope', 'consentType'))
            if ($Principal.Kind -eq 'Agent identity') {
                $Assignments += @(Invoke-MtGraphRequest -ApiVersion 'beta' -RelativeUri "servicePrincipals/microsoft.graph.agentIdentity/$($Principal.Id)/inheritedAppRoleAssignments")
                $Grants += @(Invoke-MtGraphRequest -ApiVersion 'beta' -RelativeUri "servicePrincipals/microsoft.graph.agentIdentity/$($Principal.Id)/inheritedOauth2PermissionGrants")
            }
        } catch {
            Write-Verbose "Couldn't read permissions for $($Principal.Id): $($_.Exception.Message)"
            $Unread.Add("$($Principal.Name) ($($Principal.Id))")
            continue
        }

        foreach ($Assignment in $Assignments) {
            if (-not $Assignment -or [string]$Assignment.resourceId -ne $GraphSpId) { continue }
            $Name = $RoleNames[[string]$Assignment.appRoleId]
            if ($Name) { $Permissions.Add([pscustomobject]@{ Name = $Name; Type = 'Application' }) }
        }
        foreach ($Grant in $Grants) {
            if (-not $Grant -or [string]$Grant.resourceId -ne $GraphSpId) { continue }
            # User-consented grants (consentType Principal) are MP.AIGOV.1019. Inherited grants may not carry
            # consentType; treat a missing value as admin-consented.
            if ([string]$Grant.consentType -eq 'Principal') { continue }
            foreach ($Scope in @([string]$Grant.scope -split '\s+' | Where-Object { $_ })) {
                $Permissions.Add([pscustomobject]@{ Name = $Scope; Type = 'Delegated' })
            }
        }

        $High = @($Permissions | Where-Object { $_.Name -notin $HighRiskScopes -and $_.Name -match $HighPrivilegePattern } |
                ForEach-Object { "$($_.Name) ($($_.Type))" } | Sort-Object -Unique)
        $Broad = @($Permissions | Where-Object { $_.Name -notin $HighRiskScopes -and $_.Name -notmatch $HighPrivilegePattern -and $_.Name -match '\.ReadWrite\.All$' } |
                ForEach-Object { "$($_.Name) ($($_.Type))" } | Sort-Object -Unique)
        if ($High.Count -eq 0 -and $Broad.Count -eq 0) { continue }

        $Findings.Add([pscustomobject]@{
            Name     = if ([string]::IsNullOrWhiteSpace($Principal.Name)) { $Principal.Id } else { "$($Principal.Name) ($($Principal.Id))" }
            Kind     = $Principal.Kind
            High     = if ($High.Count) { $High -join ', ' } else { '-' }
            Broad    = if ($Broad.Count) { $Broad -join ', ' } else { '-' }
            Severity = if ($High.Count) { 'High' } else { 'Medium' }
        })
    }

    $UnreadText = ''
    if ($Unread.Count -gt 0) {
        $UnreadText = " $($Unread.Count) principal(s) couldn't be read and aren't reflected in this result: $(($Unread | ForEach-Object { ConvertTo-AIGovMarkdownCell -Text $_ }) -join ', ')."
    }

    if ($Unread.Count -eq $Principals.Count) {
        Add-MtTestResultDetail -SkippedBecause Error -Result "Couldn't read permissions for any of the $($Principals.Count) agent identities or blueprint principals."
        return $null
    }

    if ($Findings.Count -eq 0) {
        Add-MtTestResultDetail -Result "Well done. None of the $($Principals.Count) agent identities or blueprint principals holds a broad Graph write permission outside MT.1223's list.$UnreadText"
        return $true
    }

    $Ordered = @($Findings | Sort-Object @{ Expression = { if ($_.Severity -eq 'High') { 0 } else { 1 } } }, Name)
    $Result = "Found $($Findings.Count) agent identity or blueprint principal(s) with broad Microsoft Graph permissions. " +
        "Replace them with narrower permissions (least privilege), or remove them.$UnreadText"
    $Result += "`n`n| Principal | Kind | Severity | High-privilege permissions | Other tenant-wide write permissions |"
    $Result += "`n| --- | --- | --- | --- | --- |"
    foreach ($Item in $Ordered) {
        $Result += "`n| $(ConvertTo-AIGovMarkdownCell -Text $Item.Name) | $($Item.Kind) | $($Item.Severity) | " +
            "$(ConvertTo-AIGovMarkdownCell -Text $Item.High) | $(ConvertTo-AIGovMarkdownCell -Text $Item.Broad) |"
    }

    Add-MtTestResultDetail -Result $Result -Severity $Ordered[0].Severity
    return $false
}
