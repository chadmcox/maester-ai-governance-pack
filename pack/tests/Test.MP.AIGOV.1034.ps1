function Test-MPAIGOV1034 {
    <#
    .SYNOPSIS
    Finds AI administration roles held permanently, by guests or non-human principals, or by too many people.
    .DESCRIPTION
    Covers three Microsoft Entra built-in roles that control Copilot and agents, all labeled
    privileged in the Entra roles reference:

    - AI Administrator (d2562ede-74db-457e-a7b6-544e236ebb61): manages all Copilot settings, the
      Integrated apps agent catalog, admin consent request policies, and the full lifecycle of agent
      identities, blueprints and agent users.
    - Agent ID Administrator (db506228-d27e-4b7d-95e5-295956d6615f): manages every agent identity,
      blueprint, blueprint principal and agent user.
    - Agent Registry Administrator (6b942400-691f-4bf0-9d12-d8a254a2baf5): manages the Agent Registry.

    Reads GET /roleManagement/directory/roleAssignmentScheduleInstances filtered to each role, with
    the principal expanded. A finding is any of:

    - Permanent active assignment: assignmentType 'Assigned' with no endDateTime. Microsoft's agent
      prerequisites guidance recommends PIM just-in-time activation for AI Administrator. (High)
    - Held by a guest user. (High)
    - Held directly by a service principal. MT.1209 already covers agent identities holding
      privileged roles; this catches other apps. (High)
    - More distinct holders than MaxHoldersPerRole (default 3). (Medium)

    When the schedule API isn't available (for example no Entra ID P2), the test falls back to
    GET /roleManagement/directory/roleAssignments, can't tell permanent from activated, and says so.
    AI Reader is not included: it can't change settings.
    .EXAMPLE
    Test-MPAIGOV1034
    .EXAMPLE
    Test-MPAIGOV1034 -MaxHoldersPerRole 5
    .LINK
    https://learn.microsoft.com/entra/identity/role-based-access-control/permissions-reference#ai-administrator
    .LINK
    https://learn.microsoft.com/microsoft-365/copilot/agent-essentials/agent-prerequisites#control-access-to-sensitive-roles-with-privileged-identity-management
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1034',
        Title        = 'AI administration roles should be eligible through PIM and held by a small number of internal users',
        Product      = 'entra',
        Feature      = 'roles',
        Area         = 'privileged-access',
        ResourceType = 'DirectoryRole',
        Severity     = 'High',
        Control      = 'nist-800-53-r5:AC-6(5)',
        Permission   = 'Graph:Application:RoleManagement.Read.Directory',
        Service      = 'Graph',
        Lifecycle    = 'Preview'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The most distinct principals that should hold each AI administration role.
        [MaesterParameter(Setting = 'AIGOV.MaxAiAdminRoleHolders')]
        [ValidateRange(1, 100)]
        [int]$MaxHoldersPerRole = 3
    )

    $Roles = [ordered]@{
        'd2562ede-74db-457e-a7b6-544e236ebb61' = 'AI Administrator'
        'db506228-d27e-4b7d-95e5-295956d6615f' = 'Agent ID Administrator'
        '6b942400-691f-4bf0-9d12-d8a254a2baf5' = 'Agent Registry Administrator'
    }

    $UsedFallback = $false
    try {
        Write-Verbose 'Reading active role assignment schedule instances for the AI administration roles.'
        $Assignments = @(
            foreach ($RoleId in $Roles.Keys) {
                Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri 'roleManagement/directory/roleAssignmentScheduleInstances' `
                    -Filter "roleDefinitionId eq '$RoleId'" -QueryParameters @{ '$expand' = 'principal' } -DisableCache
            }
        )
    } catch {
        $ScheduleError = $_
    }

    if ($ScheduleError) {
        if ($ScheduleError.Exception.Message -match '(?i)403|forbidden|authorization') {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized -Result (
                "Couldn't read role assignments (403). Confirm the RoleManagement.Read.Directory permission before re-running this check."
            )
            return $null
        }
        Write-Verbose "Schedule instances unavailable ($($ScheduleError.Exception.Message)); falling back to roleAssignments."
        $UsedFallback = $true
        try {
            $Assignments = @(
                foreach ($RoleId in $Roles.Keys) {
                    Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri 'roleManagement/directory/roleAssignments' `
                        -Filter "roleDefinitionId eq '$RoleId'" -QueryParameters @{ '$expand' = 'principal' } -DisableCache
                }
            )
        } catch {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
            return $null
        }
    }

    $Rows = @(
        $Assignments | Where-Object { $null -ne $_ } | Select-Object `
            @{ n = 'RoleId'; e = { [string]$_.roleDefinitionId } },
            @{ n = 'Role'; e = { $Roles[[string]$_.roleDefinitionId] } },
            @{ n = 'PrincipalId'; e = { [string]$_.principalId } },
            @{ n = 'Principal'; e = { if ($_.principal.userPrincipalName) { [string]$_.principal.userPrincipalName } else { [string]$_.principal.displayName } } },
            @{ n = 'PrincipalType'; e = { ([string]$_.principal.'@odata.type') -replace '^#microsoft\.graph\.', '' } },
            @{ n = 'IsGuest'; e = { [string]$_.principal.userType -eq 'Guest' } },
            @{ n = 'IsPermanent'; e = { (-not $UsedFallback) -and [string]$_.assignmentType -eq 'Assigned' -and $null -eq $_.endDateTime } }
    )

    $Findings = @(
        $Rows | ForEach-Object {
            $Reasons = @(
                if ($_.IsPermanent) { 'permanent active assignment' }
                if ($_.IsGuest) { 'guest user' }
                if ($_.PrincipalType -match '^servicePrincipal|^agent') { 'held by a non-human principal' }
            )
            if ($Reasons.Count -gt 0) { $_ | Select-Object Role, Principal, PrincipalType, @{ n = 'Reason'; e = { $Reasons -join '; ' } } }
        }
    )

    $Crowded = @(
        $Rows | Group-Object -Property Role | Where-Object {
            @($_.Group | Select-Object -ExpandProperty PrincipalId -Unique).Count -gt $MaxHoldersPerRole
        } | Select-Object @{ n = 'Role'; e = { $_.Name } }, @{ n = 'Holders'; e = { @($_.Group | Select-Object -ExpandProperty PrincipalId -Unique).Count } }
    )

    $FallbackNote = if ($UsedFallback) {
        "`n`nPIM schedule data wasn't available, so this run can't tell permanent assignments from activated ones. " +
        'Check the roles in Privileged Identity Management.'
    } else { '' }

    if ($Findings.Count -eq 0 -and $Crowded.Count -eq 0) {
        Add-MtTestResultDetail -Result (
            "Well done. $($Rows.Count) active assignment(s) to AI administration roles; none is permanent, held by a guest " +
            "or a non-human principal, and no role has more than $MaxHoldersPerRole holder(s).$FallbackNote"
        )
        return $true
    }

    $Severity = if ($Findings.Count -gt 0) { 'High' } else { 'Medium' }
    $Parts = @(
        "Found $($Findings.Count) risky assignment(s) and $($Crowded.Count) role(s) with more than $MaxHoldersPerRole holder(s)."
        if ($Findings.Count -gt 0) {
            $Findings | ConvertTo-AIGovMarkdownTable -Property 'Role', 'Principal', 'PrincipalType', 'Reason'
        }
        if ($Crowded.Count -gt 0) {
            $Crowded | ConvertTo-AIGovMarkdownTable -Property 'Role', 'Holders'
        }
    )
    Add-MtTestResultDetail -Result (($Parts -join "`n`n") + $FallbackNote) -Severity $Severity
    return $false
}
