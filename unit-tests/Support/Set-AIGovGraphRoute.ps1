# Shared helper for unit tests. Not a *.Tests.ps1 file, so Invoke-Pester doesn't run it directly.
#
# Set-AIGovGraphRoute mocks Invoke-MtGraphRequest from an ordered list of routes. Each route is
# @('<regex matched against the relative URI>', <value>[, '<regex matched against -Filter>']).
# The first matching route wins. Without the third element, the filter isn't checked.
# A value that is a string starting with 'throw:' throws that message instead of returning.
# Call it inside an It or BeforeEach block so the mock is scoped to that test.
function Set-AIGovGraphRoute {
    param([object[]]$Routes)

    $script:AIGovRoutes = $Routes
    Mock Invoke-MtGraphRequest {
        # -RelativeUri is [string[]] on Invoke-MtGraphRequest: use the first element.
        $Uri = [string]$RelativeUri[0]
        foreach ($Route in $script:AIGovRoutes) {
            if ($Route.Count -ge 3 -and [string]$Filter -notmatch $Route[2]) { continue }
            if ($Uri -match $Route[0]) {
                $Value = $Route[1]
                if ($Value -is [string] -and $Value.StartsWith('throw:')) { throw [System.Exception]::new($Value.Substring(6)) }
                if ($null -ne $UniqueId -and @($UniqueId).Count -gt 0 -and $Value -is [scriptblock]) { return (& $Value $UniqueId) }
                return $Value
            }
        }
        throw "Unexpected RelativeUri in test: $Uri"
    }
}

function New-AIGovLimit([object]$Value, [string]$Unit = 'credits') {
    if ($Value -eq 'unlimited') { return [pscustomobject]@{ '@odata.type' = '#microsoft.graph.unlimitedCostManagementQuantity' } }
    return [pscustomobject]@{ '@odata.type' = '#microsoft.graph.limitedCostManagementQuantity'; value = $Value; unit = $Unit }
}

function New-AIGovPolicy {
    param(
        [string]$Id, [string]$Name, [string]$Kind = 'groups', [string]$Status = 'enabled',
        [object]$PerUser = 'unlimited', [object[]]$Billing = @('prepaidCredits')
    )
    $Type = if ($Kind -eq 'all') { '#microsoft.graph.allUsersSpendingPolicy' } else { '#microsoft.graph.selectedGroupsSpendingPolicy' }
    [pscustomobject]@{
        '@odata.type' = $Type; id = $Id; displayName = $Name; status = $Status
        billingMethods = $Billing; periodLimit = (New-AIGovLimit 'unlimited'); perUserLimit = (New-AIGovLimit $PerUser)
    }
}
