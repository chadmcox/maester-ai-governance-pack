function Test-AIGovPackageUserAccessible {
    <#
    .SYNOPSIS
    Returns $true when users in the tenant can reach a Copilot catalog package.
    .DESCRIPTION
    A package is out of users' reach when an admin blocked it (isBlocked = true) or when it is
    available to no one (availableTo = allowedForNone). Every other package counts as reachable,
    including allowedForSome, allowedForAll and a missing availableTo or isBlocked value. Treating
    missing values as reachable errs toward reporting a finding rather than hiding one.
    Documented values: availableTo is packageAllowStatus (allowedForAll, allowedForSome,
    allowedForNone); isBlocked is Boolean.
    .EXAMPLE
    Test-AIGovPackageUserAccessible -Package $Package
    .LINK
    https://learn.microsoft.com/microsoft-365/copilot/extensibility/api/admin-settings/package/resources/copilotpackage
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        $Package
    )

    if ($null -eq $Package) { return $false }
    if ($Package.isBlocked -eq $true -or [string]$Package.isBlocked -eq 'true') { return $false }
    if ([string]$Package.availableTo -match '^(?i)allowedForNone$') { return $false }
    return $true
}
