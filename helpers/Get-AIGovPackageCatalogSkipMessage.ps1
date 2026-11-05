function Get-AIGovPackageCatalogSkipMessage {
    <#
    .SYNOPSIS
    Returns the shared dual-cause message for tests that read the Copilot package catalog.
    .DESCRIPTION
    GET /copilot/admin/catalog/packages is gated behind a Microsoft Agent 365 license. A 403 from
    this endpoint does not, by itself, prove the tenant lacks that license: it is equally consistent
    with CopilotPackages.Read.All never having been consented. Every MP.AIGOV test that reads this
    endpoint shares this wording instead of each guessing at a single cause.
    .EXAMPLE
    Add-MtTestResultDetail -SkippedBecause NotAuthorized -Result (Get-AIGovPackageCatalogSkipMessage)
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    "Couldn't read the Copilot package catalog (403). This requires a Microsoft Agent 365 license " +
        'and the CopilotPackages.Read.All permission -- confirm both before re-running this check.'
}
