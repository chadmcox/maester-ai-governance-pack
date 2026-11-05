function Get-AIGovPackageCatalogSkipMessage {
    <#
    .SYNOPSIS
    Returns the shared dual-cause message for tests that read the Copilot package catalog.
    .DESCRIPTION
    GET /copilot/admin/catalog/packages may require a Microsoft Agent 365 license depending on
    tenant -- validated 2026-11-05 against an F7-licensed test tenant where the endpoint was fully
    reachable with CopilotPackages.Read.All alone, so a license is not universally required. A 403
    from this endpoint does not, by itself, prove a license gap: it is equally consistent with
    CopilotPackages.Read.All never having been consented, or (on some tenants) an unlicensed Agent
    365 SKU. Every MP.AIGOV test that reads this endpoint shares this wording instead of each
    guessing at a single cause.
    .EXAMPLE
    Add-MtTestResultDetail -SkippedBecause NotAuthorized -Result (Get-AIGovPackageCatalogSkipMessage)
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    "Couldn't read the Copilot package catalog (403). This may require a Microsoft Agent 365 " +
        'license depending on tenant, and the CopilotPackages.Read.All permission -- confirm both ' +
        'before re-running this check.'
}
