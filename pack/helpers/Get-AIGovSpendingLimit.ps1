function Get-AIGovSpendingLimit {
    <#
    .SYNOPSIS
    Normalizes a Copilot spending-policy limit (periodLimit or perUserLimit) into a comparable object.
    .DESCRIPTION
    Cost-management limits are costManagementQuantity objects. An `@odata.type` ending in
    `unlimitedCostManagementQuantity` means no cap. Any other value is treated as a cap with a numeric
    `value` and a `unit`. A missing limit object is treated as unknown, never as unlimited and never as
    a cap, so it can't silently win or lose a "most permissive" comparison.
    .PARAMETER Limit
    The raw periodLimit or perUserLimit object from a spendingPolicy.
    .EXAMPLE
    Get-AIGovSpendingLimit -Limit $Policy.perUserLimit
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        $Limit
    )

    if ($null -eq $Limit) {
        return [pscustomobject]@{ Known = $false; Unlimited = $false; Value = $null; Unit = ''; Text = '(not set)' }
    }

    $Type = [string]$Limit.'@odata.type'
    if ($Type -match '(?i)unlimitedCostManagementQuantity$') {
        return [pscustomobject]@{ Known = $true; Unlimited = $true; Value = $null; Unit = ''; Text = 'Unlimited' }
    }

    $Number = 0.0
    if (-not [double]::TryParse([string]$Limit.value, [System.Globalization.NumberStyles]::Float,
            [System.Globalization.CultureInfo]::InvariantCulture, [ref]$Number)) {
        return [pscustomobject]@{ Known = $false; Unlimited = $false; Value = $null; Unit = ''; Text = '(unreadable)' }
    }

    $Unit = [string]$Limit.unit
    $Text = ("{0} {1}" -f $Number.ToString([System.Globalization.CultureInfo]::InvariantCulture), $Unit).Trim()
    return [pscustomobject]@{ Known = $true; Unlimited = $false; Value = $Number; Unit = $Unit; Text = $Text }
}
