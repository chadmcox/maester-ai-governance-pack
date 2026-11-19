function Invoke-AIGovAzureList {
    <#
    .SYNOPSIS
    Returns every item of an Azure Resource Manager list call, following nextLink.
    .DESCRIPTION
    Calls Invoke-MtAzureRequest and follows nextLink until the last page. Returns $null when Azure
    Resource Manager answers 401 or 403 (Invoke-MtAzureRequest returns $null for those), and an empty
    array when the list is empty, so callers can tell "no items" apart from "couldn't look".
    Other errors are left to the caller.

    Invoke-MtAzureRequest always adds ?api-version=, so the rest of the nextLink query (the skip token)
    rides along in -ApiVersion.
    .PARAMETER RelativeUri
    The resource path, such as /subscriptions/{id}/.../accounts/{name}/deployments.
    .PARAMETER ApiVersion
    The ARM api-version for the call.
    .EXAMPLE
    Invoke-AIGovAzureList -RelativeUri "$AccountId/deployments" -ApiVersion '2024-10-01'
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RelativeUri,

        [Parameter(Mandatory = $true)]
        [string]$ApiVersion
    )

    $Path = $RelativeUri
    $Version = $ApiVersion
    $Pages = 0
    $Denied = $false
    $Items = @(
        do {
            $Next = $null
            $Response = Invoke-MtAzureRequest -RelativeUri $Path -ApiVersion $Version
            if ($null -eq $Response) { $Denied = $true; break }
            $Response.value | Where-Object { $null -ne $_ }
            $Pages++

            $Next = [string]$Response.nextLink
            if ($Next) {
                $Uri = [uri]$Next
                $Path = $Uri.AbsolutePath
                $Rest = @($Uri.Query.TrimStart('?') -split '&' | Where-Object { $_ -and $_ -notmatch '^api-version=' })
                $Version = (@($ApiVersion) + $Rest) -join '&'
            }
        } while ($Next -and $Pages -lt 100)
    )
    if ($Denied -and $Pages -eq 0) { return $null }
    , $Items
}
