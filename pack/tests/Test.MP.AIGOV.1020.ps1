function Test-MPAIGOV1020 {
    <#
    .SYNOPSIS
    Finds custom or external agents and tools in the Copilot catalog that nobody uses.
    .DESCRIPTION
    Rule from chadmcox/Copilot "Agent and Tools Health Check": a custom or external agent or tool (not an
    App-kind package such as an Office add-in) is unused when it isn't blocked, has no active users in the
    last 30 days (activeUsers), was last used more than StaleDays ago or never (lastUsedDateTime), and hasn't
    been modified in StaleDays (lastModifiedDateTime). Usage fields come from the per-package detail call, so
    each custom package needs its own request. Microsoft-published packages aren't checked.
    Unused agents and tools still hold permissions and data access; blocking or removing them shrinks what
    an attacker or a mistake can reach.
    .PARAMETER StaleDays
    Days without use or change before a package is reported. Defaults to 180, matching Maester's own
    dormancy tests (MT.1117, MT.1206); 90 is a stricter option.
    .EXAMPLE
    Test-MPAIGOV1020
    .EXAMPLE
    Test-MPAIGOV1020 -StaleDays 90
    .LINK
    https://learn.microsoft.com/microsoft-365/copilot/extensibility/api/admin-settings/package/copilotpackages-get
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1020',
        Title        = 'Custom agent or tool that nobody uses should be blocked or removed',
        Product      = 'entra',
        Feature      = 'agents',
        Area         = 'ai',
        ResourceType = 'Agent',
        Severity     = 'Medium',
        Permission   = 'Graph:Application:CopilotPackages.Read.All',
        Service      = 'Graph',
        Lifecycle    = 'Preview',
        LongRunning
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $false)]
        [int] $StaleDays = 180
    )

    try {
        Write-Verbose 'Reading the Copilot package catalog.'
        $Packages = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri 'copilot/admin/catalog/packages' `
                -Select @('id', 'displayName', 'type', 'publisher', 'elementTypes', 'isBlocked', 'lastModifiedDateTime')
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

    $Cutoff = [datetime]::UtcNow.AddDays(-$StaleDays)
    $Candidates = @($Packages | Where-Object {
            $_ -and -not [string]::IsNullOrWhiteSpace([string]$_.id) -and
            -not [bool]$_.isBlocked -and
            (Get-AIGovPackageKind -ElementTypes $_.elementTypes) -ne 'App' -and
            (Test-AIGovCustomPackage -Package $_)
        })

    if ($Candidates.Count -eq 0) {
        Add-MtTestResultDetail -Result 'Well done. There are no unblocked custom or external agents or tools in the Copilot catalog to check.'
        return $true
    }

    $Unused = [System.Collections.Generic.List[pscustomobject]]::new()
    $Unread = 0
    foreach ($Package in $Candidates) {
        try {
            $Detail = Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri "copilot/admin/catalog/packages/$($Package.id)"
        } catch {
            Write-Verbose "Couldn't read package $($Package.id): $($_.Exception.Message)"
            $Unread++
            continue
        }

        $ActiveUsers = 0
        [void][int]::TryParse([string]$Detail.activeUsers, [ref]$ActiveUsers)
        if ($ActiveUsers -gt 0) { continue }

        $LastUsed = ConvertTo-AIGovUtcDate -Value $Detail.lastUsedDateTime
        if ($LastUsed -and $LastUsed -ge $Cutoff) { continue }

        $Modified = ConvertTo-AIGovUtcDate -Value $(if ($Detail.lastModifiedDateTime) { $Detail.lastModifiedDateTime } else { $Package.lastModifiedDateTime })
        if (-not $Modified -or $Modified -ge $Cutoff) { continue }

        $Unused.Add([pscustomobject]@{
            Id       = [string]$Package.id
            Name     = [string]$Package.displayName
            Kind     = Get-AIGovPackageKind -ElementTypes $Package.elementTypes
            LastUsed = if ($LastUsed) { $LastUsed.ToString('yyyy-MM-dd') } else { 'Never' }
            Modified = $Modified.ToString('yyyy-MM-dd')
        })
    }

    $UnreadText = if ($Unread -gt 0) { " $Unread package(s) couldn't be read and aren't reflected in this result." } else { '' }

    if ($Unread -gt 0 -and $Unread -eq $Candidates.Count) {
        Add-MtTestResultDetail -SkippedBecause Error -Result "Couldn't read the details of any of the $($Candidates.Count) custom package(s)."
        return $null
    }

    if ($Unused.Count -eq 0) {
        Add-MtTestResultDetail -Result "Well done. Every unblocked custom agent or tool ($($Candidates.Count)) was used or changed in the last $StaleDays days.$UnreadText"
        return $true
    }

    $Result = "Found $($Unused.Count) custom agent(s) or tool(s) with no use and no change in $StaleDays days.$UnreadText"
    $Result += "`n`n| Package ID | Name | Kind | Last used | Last modified |"
    $Result += "`n| --- | --- | --- | --- | --- |"
    foreach ($Item in ($Unused | Sort-Object Name)) {
        $Name = if ([string]::IsNullOrWhiteSpace($Item.Name)) { '(unnamed)' } else { $Item.Name }
        $Result += "`n| $(ConvertTo-AIGovMarkdownCell -Text $Item.Id) | $(ConvertTo-AIGovMarkdownCell -Text $Name) | $($Item.Kind) | $($Item.LastUsed) | $($Item.Modified) |"
    }

    Add-MtTestResultDetail -Result $Result -Severity 'Medium'
    return $false
}
