function Test-AIGovPoorDescription {
    <#
    .SYNOPSIS
    Returns $true when a description is empty, under 20 characters, or just repeats the name.
    .DESCRIPTION
    The "poor description" rule from chadmcox/Copilot "Agent and Tools Health Check".
    .EXAMPLE
    Test-AIGovPoorDescription -Description $Blueprint.description -Name $Blueprint.displayName
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Description,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Name
    )

    $Text = ([string]$Description).Trim()
    if ($Text.Length -lt 20) { return $true }
    return ($Text -eq ([string]$Name).Trim())
}
