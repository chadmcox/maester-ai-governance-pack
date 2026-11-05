function Test-MPAIGOV1007 {
    <#
    .SYNOPSIS
    Finds custom or external (non-Microsoft-published) packages available or deployed tenant-wide.
    .DESCRIPTION
    A package is Microsoft-published only if its publisher value is exactly one of: Microsoft
    Corporation, Microsoft, Microsoft 365, or Microsoft Copilot Studio. Any other publisher value --
    including a blank or null one -- is treated as custom/external for this check. Flags any
    non-Microsoft-published package where availableTo indicates allowedForAll or deployedTo indicates
    acquiredForAll: a custom or external agent should go through deliberate, scoped rollout, not
    everyone-by-default. NOT VALIDATED: requires an Agent 365-licensed test tenant to confirm the
    live field names, values, and the full set of real publisher strings in use.
    .EXAMPLE
    Test-MPAIGOV1007
    .LINK
    https://learn.microsoft.com/graph/api/copilotadmin-list-packages?view=graph-rest-1.0
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1007',
        Title        = 'Custom or external package is available or deployed tenant-wide',
        Product      = 'entra',
        Feature      = 'agents',
        Area         = 'ai',
        ResourceType = 'Agent',
        Severity     = 'High',
        Permission   = 'Graph:Application:CopilotPackages.Read.All',
        Service      = 'Graph',
        Lifecycle    = 'Preview'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Exact, written allowlist -- not an assumption. Revisit once a licensed tenant confirms the real
    # observed publisher value set; any value not in this list counts as custom/external, including
    # blank or null.
    $MicrosoftPublishedPublishers = @('Microsoft Corporation', 'Microsoft', 'Microsoft 365', 'Microsoft Copilot Studio')

    try {
        Write-Verbose 'Reading the Copilot package catalog for tenant-wide custom or external packages.'
        $Packages = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri 'copilot/admin/catalog/packages' `
                -Select @('id', 'displayName', 'publisher', 'availableTo', 'deployedTo')
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

    $TenantWideCustom = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($Package in $Packages) {
        $Publisher = [string]$Package.publisher
        if ($Publisher -in $MicrosoftPublishedPublishers) { continue }

        $IsTenantWide = ([string]$Package.availableTo -match '(?i)allowedForAll') -or
            ([string]$Package.deployedTo -match '(?i)acquiredForAll')
        if (-not $IsTenantWide) { continue }

        $TenantWideCustom.Add([pscustomobject]@{
            PackageId   = [string]$Package.id
            DisplayName = [string]$Package.displayName
            Publisher   = if ([string]::IsNullOrWhiteSpace($Publisher)) { '(blank)' } else { $Publisher }
        })
    }

    if ($TenantWideCustom.Count -eq 0) {
        Add-MtTestResultDetail -Result (
            'Well done. No custom or external package is available or deployed tenant-wide.'
        )
        return $true
    }

    $Result = "Found $($TenantWideCustom.Count) custom or external package(s) available or deployed tenant-wide."
    $Result += "`n`n| Package ID | Display name | Publisher |"
    $Result += "`n| --- | --- | --- |"
    foreach ($Item in $TenantWideCustom) {
        $Name = [string]$Item.DisplayName
        if ([string]::IsNullOrWhiteSpace($Name)) { $Name = '(unnamed)' }
        $Name = [System.Net.WebUtility]::HtmlEncode($Name) -replace '\|', '&#124;'
        $Name = $Name -replace "`r?`n", ' '
        $Result += "`n| $($Item.PackageId) | $Name | $($Item.Publisher) |"
    }

    Add-MtTestResultDetail -Result $Result -Severity 'High'
    return $false
}
