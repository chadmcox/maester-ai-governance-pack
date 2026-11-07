function Add-AIGovSpendingAudiencePolicy {
    <#
    .SYNOPSIS
    Records that a spending policy applies to an audience (a group, or 'All users').
    .DESCRIPTION
    Used by MP.AIGOV.1015 to build, per audience, the list of enabled spending policies that apply to it,
    with each policy's per-user limit normalized by Get-AIGovSpendingLimit. The Audiences hashtable is
    updated in place.
    .EXAMPLE
    Add-AIGovSpendingAudiencePolicy -Audiences $Audiences -Key $Group.id -DisplayName $Group.displayName -Policy $Policy -IsGroupScoped
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Audiences,

        [Parameter(Mandatory = $true)]
        [string]$Key,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$DisplayName,

        [Parameter(Mandatory = $true)]
        $Policy,

        [switch]$IsGroupScoped
    )

    if (-not $Audiences.ContainsKey($Key)) {
        $Audiences[$Key] = [pscustomobject]@{
            Key         = $Key
            DisplayName = $DisplayName
            Policies    = [System.Collections.Generic.List[pscustomobject]]::new()
        }
    }
    $Audiences[$Key].Policies.Add([pscustomobject]@{
        Name          = [string]$Policy.displayName
        IsGroupScoped = [bool]$IsGroupScoped
        PerUser       = Get-AIGovSpendingLimit -Limit $Policy.perUserLimit
    })
}
