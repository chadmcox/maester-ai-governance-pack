function Test-MPAIGOV1003 {
    <#
    .SYNOPSIS
    Finds agents assigned directly to users instead of via a group.
    .DESCRIPTION
    The audience collections (allowedUsersAndGroups, acquireUsersAndGroups) are only returned by the
    per-package detail call, GET /copilot/admin/catalog/packages/{id} -- the list call does not
    return them, so every package in the catalog needs its own detail request. Flags entries where
    resourceType eq 'user': a direct user assignment has no group to audit membership through and no
    single place to see who has access. Reading this endpoint may require a Microsoft Agent 365
    license depending on tenant -- validated 2026-11-05 against an F7-licensed test tenant where
    CopilotPackages.Read.All alone was sufficient.
    .EXAMPLE
    Test-MPAIGOV1003
    .LINK
    https://learn.microsoft.com/graph/api/copilotadmin-get-package?view=graph-rest-1.0
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1003',
        Title        = 'Agent is assigned directly to users instead of via a group',
        Product      = 'entra',
        Feature      = 'agents',
        Area         = 'ai',
        ResourceType = 'Agent',
        Severity     = 'Low',
        Permission   = 'Graph:Application:CopilotPackages.Read.All',
        Service      = 'Graph',
        Lifecycle    = 'Preview',
        LongRunning
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        Write-Verbose 'Reading the Copilot package catalog, then each package detail, for direct user assignments.'
        $Packages = @(Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri 'copilot/admin/catalog/packages' -Select @('id', 'displayName'))
    } catch {
        $ErrorRecord = $_
    }
    if ($ErrorRecord) {
        if ($ErrorRecord.Exception.Message -match '(?i)403|forbidden|authorization') {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized -Result (Get-AIGovPackageCatalogSkipMessage)
        } else {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $ErrorRecord
        }
        return $null
    }

    $DirectAssignments = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($Package in $Packages) {
        $PackageId = [string]$Package.id
        if ([string]::IsNullOrWhiteSpace($PackageId)) { continue }

        try {
            $Detail = Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri "copilot/admin/catalog/packages/$PackageId" `
                -Select @('id', 'allowedUsersAndGroups', 'acquireUsersAndGroups')
        } catch {
            # One package's detail call failing (for example, it was removed between the list and the
            # detail call) should not fail every other package already evaluated.
            Write-Verbose "Skipping package $PackageId after a detail-read error: $($_.Exception.Message)"
            continue
        }

        $DirectUsers = @(
            @($Detail.allowedUsersAndGroups) + @($Detail.acquireUsersAndGroups) |
                Where-Object { $_ -and $_.resourceType -eq 'user' }
        )
        if ($DirectUsers.Count -gt 0) {
            $DirectAssignments.Add([pscustomobject]@{
                PackageId    = $PackageId
                DisplayName  = [string]$Package.displayName
                UserCount    = $DirectUsers.Count
            })
        }
    }

    if ($DirectAssignments.Count -eq 0) {
        Add-MtTestResultDetail -Result (
            'Well done. No agent is assigned directly to users; every assignment goes through a group.'
        )
        return $true
    }

    $Result = "Found $($DirectAssignments.Count) agent(s) assigned directly to one or more users."
    $Result += "`n`n| Package ID | Display name | Directly assigned user count |"
    $Result += "`n| --- | --- | --- |"
    foreach ($Item in $DirectAssignments) {
        $DisplayName = [string]$Item.DisplayName
        if ([string]::IsNullOrWhiteSpace($DisplayName)) { $DisplayName = '(unnamed)' }
        $DisplayName = [System.Net.WebUtility]::HtmlEncode($DisplayName) -replace '\|', '&#124;'
        $DisplayName = $DisplayName -replace "`r?`n", ' '
        $Result += "`n| $($Item.PackageId) | $DisplayName | $($Item.UserCount) |"
    }

    Add-MtTestResultDetail -Result $Result -Severity 'Low'
    return $false
}
