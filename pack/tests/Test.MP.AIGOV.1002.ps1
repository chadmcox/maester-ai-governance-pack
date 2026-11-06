function Test-MPAIGOV1002 {
    <#
    .SYNOPSIS
    Finds blocked packages with an open pending install or consent request.
    .DESCRIPTION
    A package the tenant has blocked (isBlocked) should have no live path to installation. A pending
    request against it (requestStatus/requestType) means a user can still be waiting on, or an admin
    can still approve, an install the tenant already decided to block. Reading this endpoint may
    require a Microsoft Agent 365 license depending on tenant -- validated 2026-11-05 against an
    F7-licensed test tenant where CopilotPackages.Read.All alone was sufficient.
    .EXAMPLE
    Test-MPAIGOV1002
    .LINK
    https://learn.microsoft.com/graph/api/copilotadmin-list-packages?view=graph-rest-1.0
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1002',
        Title        = 'Blocked package has an open pending install or consent request',
        Product      = 'entra',
        Feature      = 'agents',
        Area         = 'ai',
        ResourceType = 'Agent',
        Severity     = 'Low',
        Permission   = 'Graph:Application:CopilotPackages.Read.All',
        Service      = 'Graph',
        Lifecycle    = 'Preview'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        Write-Verbose 'Reading the Copilot package catalog for blocked packages with a pending request.'
        $Packages = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri 'copilot/admin/catalog/packages' `
                -Select @('id', 'displayName', 'isBlocked', 'requestStatus', 'requestType')
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

    $PendingBlocked = @($Packages | Where-Object {
        $_.isBlocked -eq $true -and -not [string]::IsNullOrWhiteSpace([string]$_.requestStatus) -and
        [string]$_.requestStatus -notmatch '(?i)^(none|completed|cancell?ed|denied)$'
    })

    if ($PendingBlocked.Count -eq 0) {
        Add-MtTestResultDetail -Result (
            'Well done. No blocked package has an open pending install or consent request.'
        )
        return $true
    }

    $Result = "Found $($PendingBlocked.Count) blocked package(s) with an open pending request."
    $Result += "`n`n| Package ID | Display name | Request status | Request type |"
    $Result += "`n| --- | --- | --- | --- |"
    foreach ($Package in $PendingBlocked) {
        $DisplayName = [string]$Package.displayName
        if ([string]::IsNullOrWhiteSpace($DisplayName)) { $DisplayName = '(unnamed)' }
        $DisplayName = [System.Net.WebUtility]::HtmlEncode($DisplayName) -replace '\|', '&#124;'
        $DisplayName = $DisplayName -replace "`r?`n", ' '
        $Result += "`n| $([string]$Package.id) | $DisplayName | $([string]$Package.requestStatus) | $([string]$Package.requestType) |"
    }

    Add-MtTestResultDetail -Result $Result -Severity 'Low'
    return $false
}
