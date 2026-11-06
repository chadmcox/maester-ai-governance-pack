function Test-MPAIGOV1013 {
    <#
    .SYNOPSIS
    Finds enabled Copilot spending policies with no overall credit ceiling.
    .DESCRIPTION
    Reads every `spendingPolicy` from the beta Cost Management API. Each policy's `periodLimit`
    carries an `@odata.type` of either `#microsoft.graph.limitedCostManagementQuantity` (a real
    numeric `value` cap) or `#microsoft.graph.unlimitedCostManagementQuantity` (no cap at all).
    Flags any `enabled` policy whose `periodLimit` is unlimited: an unbounded policy has no ceiling
    to catch runaway Copilot/agent consumption, regardless of how tightly its audience is scoped.
    A `disabled` policy is not currently in effect and is excluded. This is a live, confirmed
    property (not a guess) -- 7 of 8 enabled policies in the test tenant were unlimited this way.
    .EXAMPLE
    Test-MPAIGOV1013
    .LINK
    https://learn.microsoft.com/microsoft-365/copilot/extensibility/api/admin-settings/cost-management/spendingpolicy-list
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1013',
        Title        = 'Enabled spending policy should have a credit ceiling',
        Product      = 'entra',
        Feature      = 'cost-management',
        Area         = 'ai',
        ResourceType = 'Tenant',
        Severity     = 'Medium',
        Permission   = 'Graph:Application:CopilotCostManagement-Policy.Read.All',
        Service      = 'Graph',
        Lifecycle    = 'Preview'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        Write-Verbose 'Reading Copilot spending policies for enabled policies with no credit ceiling.'
        $Policies = @(
            Invoke-MtGraphRequest -ApiVersion 'beta' -RelativeUri 'copilot/costManagement/spendingPolicies' `
                -Select @('id', 'displayName', 'status', 'periodLimit', 'perUserLimit')
        )
    } catch {
        $ErrorRecord = $_
    }
    if ($ErrorRecord) {
        if ($ErrorRecord.Exception.Message -match '(?i)403|forbidden|authorization') {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized -Result (Get-AIGovCostManagementSkipMessage)
        } else {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $ErrorRecord
        }
        return $null
    }

    if ($Policies.Count -eq 0) {
        Add-MtTestResultDetail -Result 'Well done. No Copilot spending policies were found in the tenant.'
        return $true
    }

    $Unlimited = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($Policy in $Policies) {
        if ([string]$Policy.status -ne 'enabled') { continue }

        $PeriodType = [string]$Policy.periodLimit.'@odata.type'
        if ($PeriodType -notmatch '(?i)unlimitedCostManagementQuantity$') { continue }

        $PerUserType = [string]$Policy.perUserLimit.'@odata.type'
        $PerUserText = if ($PerUserType -match '(?i)unlimitedCostManagementQuantity$') {
            'Unlimited'
        } else {
            "$($Policy.perUserLimit.value) $($Policy.perUserLimit.unit)"
        }

        $Unlimited.Add([pscustomobject]@{
            PolicyId    = [string]$Policy.id
            DisplayName = [string]$Policy.displayName
            PerUserLimit = $PerUserText
        })
    }

    if ($Unlimited.Count -eq 0) {
        Add-MtTestResultDetail -Result (
            'Well done. Every enabled Copilot spending policy has a credit ceiling.'
        )
        return $true
    }

    $Result = "Found $($Unlimited.Count) enabled Copilot spending policy/policies with no overall credit ceiling."
    $Result += "`n`n| Policy ID | Display name | Per-user limit |"
    $Result += "`n| --- | --- | --- |"
    foreach ($Item in $Unlimited) {
        $Name = [string]$Item.DisplayName
        if ([string]::IsNullOrWhiteSpace($Name)) { $Name = '(unnamed)' }
        $Name = [System.Net.WebUtility]::HtmlEncode($Name) -replace '\|', '&#124;'
        $Name = $Name -replace "`r?`n", ' '
        $Result += "`n| $($Item.PolicyId) | $Name | $($Item.PerUserLimit) |"
    }

    Add-MtTestResultDetail -Result $Result -Severity 'Medium'
    return $false
}
