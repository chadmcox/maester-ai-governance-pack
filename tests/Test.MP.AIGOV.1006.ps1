function Test-MPAIGOV1006 {
    <#
    .SYNOPSIS
    Finds agents with an empty or placeholder display name or description.
    .DESCRIPTION
    An agent with no description, or an obvious placeholder name (test, demo, copy, draft, untitled,
    and similar), gives reviewers nothing to judge its purpose by. NOT VALIDATED: requires an Agent
    365-licensed test tenant to confirm the live field names and typical placeholder values.
    .EXAMPLE
    Test-MPAIGOV1006
    .LINK
    https://learn.microsoft.com/graph/api/copilotadmin-list-packages?view=graph-rest-1.0
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1006',
        Title        = 'Agent display name or description is empty or a placeholder value',
        Product      = 'entra',
        Feature      = 'agents',
        Area         = 'ai',
        ResourceType = 'Agent',
        Severity     = 'Info',
        Permission   = 'Graph:Application:CopilotPackages.Read.All',
        Service      = 'Graph',
        Lifecycle    = 'Preview'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Patterns treated as placeholder names, matched case-insensitively against the whole display name.
        [Parameter(Mandatory = $false)]
        [string[]] $PlaceholderNamePattern = @('^test', '^demo', 'copy of', '^draft', '^untitled', '^new agent$', '^my agent$')
    )

    try {
        Write-Verbose 'Reading the Copilot package catalog for empty or placeholder names and descriptions.'
        $Packages = @(Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri 'copilot/admin/catalog/packages' -Select @('id', 'displayName', 'shortDescription', 'longDescription'))
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

    $NamePattern = ($PlaceholderNamePattern -join '|')

    $Unclear = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($Package in $Packages) {
        $DisplayName = [string]$Package.displayName
        $ShortDescription = [string]$Package.shortDescription
        $LongDescription = [string]$Package.longDescription
        $Reasons = [System.Collections.Generic.List[string]]::new()

        if ([string]::IsNullOrWhiteSpace($DisplayName)) {
            $Reasons.Add('Empty display name.')
        } elseif ($NamePattern -and ($DisplayName -match "(?i)($NamePattern)")) {
            $Reasons.Add('Display name looks like a placeholder.')
        }
        if ([string]::IsNullOrWhiteSpace($ShortDescription) -and [string]::IsNullOrWhiteSpace($LongDescription)) {
            $Reasons.Add('Empty description.')
        }

        if ($Reasons.Count -gt 0) {
            $Unclear.Add([pscustomobject]@{
                PackageId   = [string]$Package.id
                DisplayName = $DisplayName
                Reason      = ($Reasons -join ' ')
            })
        }
    }

    if ($Unclear.Count -eq 0) {
        Add-MtTestResultDetail -Result (
            'Well done. Every agent has a clear display name and a description.'
        )
        return $true
    }

    $Result = "Found $($Unclear.Count) agent(s) with an empty or placeholder display name or description."
    $Result += "`n`n| Package ID | Display name | Reason |"
    $Result += "`n| --- | --- | --- |"
    foreach ($Item in $Unclear) {
        $Name = [string]$Item.DisplayName
        if ([string]::IsNullOrWhiteSpace($Name)) { $Name = '(empty)' }
        $Name = [System.Net.WebUtility]::HtmlEncode($Name) -replace '\|', '&#124;'
        $Name = $Name -replace "`r?`n", ' '
        $Result += "`n| $($Item.PackageId) | $Name | $($Item.Reason) |"
    }

    Add-MtTestResultDetail -Result $Result -Severity 'Info'
    return $false
}
