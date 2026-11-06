function Get-AIGovCostManagementSkipMessage {
    <#
    .SYNOPSIS
    Returns the shared dual-cause message for tests that read Copilot cost-management data.
    .DESCRIPTION
    GET /copilot/costManagement/spendingPolicies (and its assignedGroups sub-resource) are beta
    endpoints gated by the CopilotCostManagement-Policy.Read.All and
    CopilotCostManagement-Assignment.Read.All permissions respectively -- confirmed live 2026-11-06
    against an F7-licensed test tenant, where both were reachable once consented, with no separate
    Agent 365 license requirement observed on this surface. A 403 from either endpoint does not, by
    itself, prove a license gap: it is equally consistent with the relevant permission never having
    been consented. Every MP.AIGOV test that reads this surface shares this wording instead of each
    guessing at a single cause.
    .EXAMPLE
    Add-MtTestResultDetail -SkippedBecause NotAuthorized -Result (Get-AIGovCostManagementSkipMessage)
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    "Couldn't read Copilot cost-management data (403). This needs CopilotCostManagement-" +
        'Policy.Read.All (and CopilotCostManagement-Assignment.Read.All for group-backed ' +
        'policies), and may also depend on tenant licensing -- confirm both before re-running ' +
        'this check.'
}
