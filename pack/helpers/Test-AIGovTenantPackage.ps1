function Test-AIGovTenantPackage {
    <#
    .SYNOPSIS
    Returns $true when a Copilot catalog package was built in this tenant (not Microsoft's, not a vendor's).
    .DESCRIPTION
    Same rule as chadmcox/Copilot "Agent and Tools Health Check": a package is built in the tenant when its
    type isn't firstParty or microsoft (Microsoft-published) and isn't thirdParty or external (a vendor's).
    Copilot Studio agents shared in the tenant are type 'shared'. Only these can be renamed, redescribed
    or moved to Agent ID by the tenant; a vendor's name and description are the vendor's to fix. When
    type is missing, falls back to Test-AIGovCustomPackage, which errs toward checking the package.
    .EXAMPLE
    Test-AIGovTenantPackage -Package $Package
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        $Package
    )

    $Type = [string]$Package.type
    if ([string]::IsNullOrWhiteSpace($Type)) { return (Test-AIGovCustomPackage -Package $Package) }
    return ($Type -notin @('firstParty', 'microsoft', 'thirdParty', 'external'))
}
