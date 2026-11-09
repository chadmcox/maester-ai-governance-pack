function Test-AIGovCustomPackage {
    <#
    .SYNOPSIS
    Returns $true when a Copilot catalog package is custom or external (not Microsoft-published).
    .DESCRIPTION
    Same rule as MP.AIGOV.1007: a package is Microsoft-published when its type is 'firstParty' (the value
    observed live; chadmcox/Copilot's script compares against 'microsoft'). When type is missing, falls back
    to a short list of Microsoft publisher names.
    .EXAMPLE
    Test-AIGovCustomPackage -Package $Package
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        $Package
    )

    $Type = [string]$Package.type
    if ([string]::IsNullOrWhiteSpace($Type)) {
        return ([string]$Package.publisher -notin @('Microsoft Corporation', 'Microsoft', 'Microsoft 365', 'Microsoft Copilot Studio'))
    }
    return ($Type -notin @('firstParty', 'microsoft'))
}
