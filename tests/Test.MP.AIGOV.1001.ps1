function Test-MPAIGOV1001 {
    <#
    .SYNOPSIS
    Finds tenants where Copilot agent catalog adoption is below a configurable threshold.
    .DESCRIPTION
    Reads the Microsoft 365 Copilot usage report for the fixed D90 report period and compares the
    share of reported users with agent activity against a configurable threshold (default 5%). Only
    runs when the package catalog reports at least one agent -- so this also depends on the Package
    Management API (and therefore an Agent 365 license), not just the usage report. Skips when fewer
    than 20 users are reported (too small a sample) and when the undocumented agent-activity column
    cannot be found by name. NOT VALIDATED: requires an Agent 365-licensed test tenant to confirm the
    live report column names and the package catalog agent count.
    .EXAMPLE
    Test-MPAIGOV1001
    .EXAMPLE
    Test-MPAIGOV1001 -AdoptionThresholdPercent 10
    .LINK
    https://learn.microsoft.com/graph/api/reportroot-getmicrosoft365copilotusageuserdetail?view=graph-rest-beta
    .LINK
    https://learn.microsoft.com/graph/api/copilotadmin-list-packages?view=graph-rest-1.0
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1001',
        Title        = 'Agent catalog adoption is below a configurable threshold over the D90 report period',
        Product      = 'entra',
        Feature      = 'agents',
        Area         = 'ai',
        ResourceType = 'Agent',
        Severity     = 'Low',
        Permission   = 'Graph:Application:Reports.Read.All|Graph:Application:CopilotPackages.Read.All',
        Service      = 'Graph',
        Lifecycle    = 'Preview'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Minimum share of reported users with agent activity, as a percentage. Defaults to 5.
        # The D90 report period itself is fixed by the Graph API and is not configurable.
        [Parameter(Mandatory = $false)]
        [int] $AdoptionThresholdPercent = 5
    )

    try {
        Write-Verbose 'Checking the package catalog for at least one agent before reading usage.'
        $Packages = @(Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri 'copilot/admin/catalog/packages' -Select @('id', 'elementTypes'))
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

    # elementTypes is a String collection per package; Learn's documented example values for an agent
    # are 'bot' and 'declarativeAgent' (case as published). Matched case-insensitively here since the
    # live casing has not been confirmed against a licensed tenant.
    $AgentPackages = @($Packages | Where-Object { @($_.elementTypes) | Where-Object { $_ -match '(?i)^(bot|declarativeAgent)$' } })
    if ($AgentPackages.Count -eq 0) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'The package catalog reports no agents, so adoption has nothing to measure.'
        return $null
    }

    try {
        Write-Verbose 'Reading the Microsoft 365 Copilot usage report for the fixed D90 period.'
        $Rows = @(Invoke-MtGraphRequest -ApiVersion 'beta' -RelativeUri "copilot/reports/getMicrosoft365CopilotUsageUserDetail(period='D90')")
    } catch {
        $ErrorRecord = $_
    }
    if ($ErrorRecord) {
        if ($ErrorRecord.Exception.Message -match '(?i)403|forbidden|authorization') {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized -Result (
                "Couldn't read the Copilot usage report (403). This requires Reports.Read.All and the " +
                'Reports Reader role -- confirm both before re-running this check.'
            )
        } else {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $ErrorRecord
        }
        return $null
    }

    if ($Rows.Count -lt 20) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Fewer than 20 users were reported ($($Rows.Count)); the adoption percentage would not be reliable."
        return $null
    }

    # The agent-activity column is undocumented and has changed before; find it by name instead of
    # hard-coding it. Any property name containing both 'Agent' and 'Activity' qualifies.
    $SampleRow = $Rows | Select-Object -First 1
    $ActivityColumn = @($SampleRow.PSObject.Properties.Name) | Where-Object { $_ -match '(?i)agent' -and $_ -match '(?i)activity' } | Select-Object -First 1

    if (-not $ActivityColumn) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'No column in the usage report matched the *Agent*Activity* name pattern; the report shape may have changed.'
        return $null
    }

    Write-Verbose "Using report column '$ActivityColumn' as the agent-activity signal."
    $ActiveUsers = @($Rows | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.$ActivityColumn) })
    $AdoptionPercent = [math]::Round(($ActiveUsers.Count / $Rows.Count) * 100, 1)

    if ($AdoptionPercent -ge $AdoptionThresholdPercent) {
        Add-MtTestResultDetail -Result (
            "Well done. Agent catalog adoption is $AdoptionPercent% over the D90 period, at or above the $AdoptionThresholdPercent% threshold."
        )
        return $true
    }

    Add-MtTestResultDetail -Result (
        "Agent catalog adoption is $AdoptionPercent% over the D90 period ($($ActiveUsers.Count) of $($Rows.Count) reported users), below the $AdoptionThresholdPercent% threshold."
    ) -Severity 'Low'
    return $false
}
