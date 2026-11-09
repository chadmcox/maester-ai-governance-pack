function Test-MPAIGOV1021 {
    <#
    .SYNOPSIS
    Finds groups that agents and tools are assigned to that no longer exist or have no one accountable.
    .DESCRIPTION
    For every agent or tool in the Copilot catalog (not App-kind packages), reads the per-package audience
    (allowedUsersAndGroups and acquireUsersAndGroups, resourceType group) and applies the group rules from
    chadmcox/Copilot "Agent and Tools Health Check":
      - Medium: an assigned group no longer exists.
      - Medium: an assigned group has fewer than MinOwnerCount owners (default 2).
      - Low:    an assigned group has no description.
    The group is who can use the agent, so someone has to own its membership. Direct user assignment is
    MP.AIGOV.1003.
    .PARAMETER MinOwnerCount
    Minimum number of owners an assigned group should have.
    .EXAMPLE
    Test-MPAIGOV1021
    .LINK
    https://learn.microsoft.com/microsoft-365/copilot/extensibility/api/admin-settings/package/copilotpackages-get
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1021',
        Title        = 'Group an agent or tool is assigned to should exist, have two owners and a description',
        Product      = 'entra',
        Feature      = 'agents',
        Area         = 'ai',
        ResourceType = 'Group',
        Severity     = 'Medium',
        Permission   = 'Graph:Application:CopilotPackages.Read.All|Graph:Application:Group.Read.All',
        Service      = 'Graph',
        Lifecycle    = 'Preview',
        LongRunning
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $false)]
        [int] $MinOwnerCount = 2
    )

    try {
        Write-Verbose 'Reading the Copilot package catalog.'
        $Packages = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri 'copilot/admin/catalog/packages' -Select @('id', 'displayName', 'elementTypes')
        )
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

    $Candidates = @($Packages | Where-Object {
            $_ -and -not [string]::IsNullOrWhiteSpace([string]$_.id) -and (Get-AIGovPackageKind -ElementTypes $_.elementTypes) -ne 'App'
        })

    # Group ID -> names of the packages assigned to it.
    $GroupPackages = @{}
    $Unread = [System.Collections.Generic.List[string]]::new()
    foreach ($Package in $Candidates) {
        try {
            $Detail = Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri "copilot/admin/catalog/packages/$($Package.id)" `
                -Select @('id', 'allowedUsersAndGroups', 'acquireUsersAndGroups')
        } catch {
            Write-Verbose "Couldn't read package $($Package.id): $($_.Exception.Message)"
            $Unread.Add([string]$Package.displayName)
            continue
        }
        $GroupIds = @(@($Detail.allowedUsersAndGroups) + @($Detail.acquireUsersAndGroups) |
                Where-Object { $_ -and [string]$_.resourceType -eq 'group' -and $_.resourceId } |
                ForEach-Object { [string]$_.resourceId } | Sort-Object -Unique)
        foreach ($GroupId in $GroupIds) {
            if (-not $GroupPackages.ContainsKey($GroupId)) { $GroupPackages[$GroupId] = [System.Collections.Generic.List[string]]::new() }
            $GroupPackages[$GroupId].Add([string]$Package.displayName)
        }
    }

    if ($Candidates.Count -gt 0 -and $Unread.Count -eq $Candidates.Count) {
        Add-MtTestResultDetail -SkippedBecause Error -Result "Couldn't read the details of any of the $($Candidates.Count) agent or tool package(s)."
        return $null
    }

    $Findings = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($GroupId in $GroupPackages.Keys) {
        $Used = ($GroupPackages[$GroupId] | Sort-Object -Unique) -join ', '
        try {
            $Group = Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri "groups/$GroupId" -Select @('id', 'displayName', 'description')
            $Owners = @(Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri "groups/$GroupId/owners" -Select @('id') | Where-Object { $_ })
        } catch {
            if (Test-AIGovNotFoundError -ErrorRecord $_) {
                $Findings.Add([pscustomobject]@{ Group = $GroupId; Packages = $Used; Severity = 'Medium'; Check = 'Group no longer exists'; Fix = 'Assign the agent or tool to the right group.' })
            } else {
                Write-Verbose "Couldn't read group $GroupId`: $($_.Exception.Message)"
                $Unread.Add("group $GroupId")
            }
            continue
        }

        $Name = if ([string]::IsNullOrWhiteSpace([string]$Group.displayName)) { $GroupId } else { "$($Group.displayName) ($GroupId)" }
        if ($Owners.Count -lt $MinOwnerCount) {
            $Findings.Add([pscustomobject]@{ Group = $Name; Packages = $Used; Severity = 'Medium'; Check = "Has $($Owners.Count) owner(s)"; Fix = "Add owners so there are at least $MinOwnerCount." })
        }
        if ([string]::IsNullOrWhiteSpace([string]$Group.description)) {
            $Findings.Add([pscustomobject]@{ Group = $Name; Packages = $Used; Severity = 'Low'; Check = 'No description'; Fix = 'Describe the group and name the agent or tool it is for.' })
        }
    }

    $UnreadText = ''
    if ($Unread.Count -gt 0) {
        $UnreadText = " $($Unread.Count) item(s) couldn't be read and aren't reflected in this result: $(($Unread | ForEach-Object { ConvertTo-AIGovMarkdownCell -Text $_ }) -join ', ')."
    }

    if ($Findings.Count -eq 0) {
        $Scope = if ($GroupPackages.Count -eq 0) { 'No agent or tool is assigned to a group.' } else { "All $($GroupPackages.Count) group(s) that agents and tools are assigned to exist, have at least $MinOwnerCount owners and a description." }
        Add-MtTestResultDetail -Result "Well done. $Scope$UnreadText"
        return $true
    }

    $Rank = @{ High = 0; Medium = 1; Low = 2 }
    $Ordered = @($Findings | Sort-Object @{ Expression = { $Rank[$_.Severity] } }, Group)
    $Result = "Found $($Findings.Count) problem(s) with groups that agents and tools are assigned to.$UnreadText"
    $Result += "`n`n| Group | Agents and tools | Severity | Check | Fix |"
    $Result += "`n| --- | --- | --- | --- | --- |"
    foreach ($Item in $Ordered) {
        $Result += "`n| $(ConvertTo-AIGovMarkdownCell -Text $Item.Group) | $(ConvertTo-AIGovMarkdownCell -Text $Item.Packages) | $($Item.Severity) | " +
            "$(ConvertTo-AIGovMarkdownCell -Text $Item.Check) | $(ConvertTo-AIGovMarkdownCell -Text $Item.Fix) |"
    }

    Add-MtTestResultDetail -Result $Result -Severity $Ordered[0].Severity
    return $false
}
