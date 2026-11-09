function Get-AIGovCopilotLicenseState {
    <#
    .SYNOPSIS
    Returns Working, Turned off, Error or None for a user's Microsoft 365 Copilot license.
    .DESCRIPTION
    Same rule as chadmcox/Copilot "Billing Health Check": a license is Copilot when its SKU includes one of
    the Copilot service plans. It is Working when it's assigned, the Copilot plan isn't in disabledPlans,
    and its licenseAssignmentStates entry isn't in an error or disabled state.
    .PARAMETER User
    A user object with assignedLicenses and licenseAssignmentStates.
    .PARAMETER CopilotSkuIds
    SKU IDs (from subscribedSkus) that include a Copilot service plan.
    .PARAMETER CopilotServicePlanIds
    The Copilot service plan IDs.
    .EXAMPLE
    Get-AIGovCopilotLicenseState -User $User -CopilotSkuIds $SkuIds -CopilotServicePlanIds $PlanIds
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        $User,

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [string[]]$CopilotSkuIds = @(),

        [Parameter(Mandatory = $true)]
        [string[]]$CopilotServicePlanIds
    )

    $Copilot = @($User.assignedLicenses | Where-Object { $_ -and [string]$_.skuId -in $CopilotSkuIds })
    if ($Copilot.Count -eq 0) { return 'None' }

    $States = @($User.licenseAssignmentStates | Where-Object { $_ -and [string]$_.skuId -in $CopilotSkuIds })
    if ($States.Count -gt 0 -and -not ($States | Where-Object { [string]$_.state -in 'Active', 'ActiveWithError' })) {
        return 'Error'
    }

    foreach ($License in $Copilot) {
        $Disabled = @($License.disabledPlans | ForEach-Object { [string]$_ })
        if ($CopilotServicePlanIds | Where-Object { $_ -notin $Disabled }) { return 'Working' }
    }
    return 'Turned off'
}
