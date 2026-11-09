function Test-MPAIGOV1007 {
    <#
    .SYNOPSIS
    Finds custom or external (non-Microsoft-published) packages available or deployed tenant-wide.
    .DESCRIPTION
    A package is Microsoft-published when its `type` property equals 'firstParty' (case-insensitive).
    chadmcox/Copilot's Get-AgentToolsHealth.ps1 compares `type` against the literal 'microsoft', but
    live validation against the test tenant (2026-11-05) showed the API actually returns 'firstParty'
    or 'thirdParty' -- never the literal 'microsoft' -- so that comparison would misclassify every
    Microsoft-published package (observed: "Sales", "Service", "Frontline Agent (Preview)", all
    `type: firstParty`, `publisher: Microsoft Corporation`) as custom/external. This test uses the
    observed value instead. Any `type` other than 'firstParty', including a blank or null one, is
    treated as custom/external. If `type` itself is missing, falls back to an explicit publisher
    allowlist (Microsoft Corporation, Microsoft, Microsoft 365, Microsoft Copilot Studio) as a
    secondary signal only. Office add-ins and tabs
    ("App"-kind packages, matched the same way as Get-PackageKind in that script: elementTypes without
    declarativeAgent/customEngine/bot/skill/connector/mcp/plugin/action) are out of scope and excluded
    before the custom/external check runs. Flags any remaining non-Microsoft-published package where
    availableTo indicates allowedForAll or deployedTo indicates acquiredForAll: a custom or external
    agent or tool should go through deliberate, scoped rollout, not everyone-by-default. Reading this
    endpoint may require a Microsoft Agent 365 license depending on tenant -- validated 2026-11-05
    against an F7-licensed test tenant where CopilotPackages.Read.All alone was sufficient.
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

    # Fallback only -- used when a package's `type` property is missing. Primary signal is `type -ne
    # 'microsoft'`, matching chadmcox/Copilot's Get-AgentToolsHealth.ps1.
    $MicrosoftPublishedPublishers = @('Microsoft Corporation', 'Microsoft', 'Microsoft 365', 'Microsoft Copilot Studio')

    try {
        Write-Verbose 'Reading the Copilot package catalog for tenant-wide custom or external packages.'
        $Packages = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri 'copilot/admin/catalog/packages' `
                -Select @('id', 'displayName', 'type', 'publisher', 'availableTo', 'deployedTo', 'elementTypes', 'isBlocked')
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
        # Same kind test as Get-PackageKind in chadmcox/Copilot's Get-AgentToolsHealth.ps1: a package
        # whose elementTypes don't look like an agent or a tool is an "App" (Office add-in/tab) and is
        # out of scope for this check.
        $ElementTypeText = @($Package.elementTypes) -join ' '
        $IsAgentOrTool = $ElementTypeText -match '(?i)declarativeAgent|customEngine|bot|skill|connector|mcp|plugin|action'
        if (-not $IsAgentOrTool) { continue }

        $Type = [string]$Package.type
        $Publisher = [string]$Package.publisher
        if ([string]::IsNullOrWhiteSpace($Type)) {
            $IsCustom = $Publisher -notin $MicrosoftPublishedPublishers
        } else {
            # -ne is case-insensitive in PowerShell. Observed live value for Microsoft-published
            # packages is 'firstParty' (not the literal 'microsoft' in chadmcox/Copilot's script).
            $IsCustom = $Type -ne 'firstParty'
        }
        if (-not $IsCustom) { continue }

        # A blocked package can't be used even if it's still marked available to everyone.
        if (-not (Test-AIGovPackageUserAccessible -Package $Package)) { continue }

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
