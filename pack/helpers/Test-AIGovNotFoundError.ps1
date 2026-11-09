function Test-AIGovNotFoundError {
    <#
    .SYNOPSIS
    Returns $true when a Graph error means the object doesn't exist (404), not a permission or service problem.
    .DESCRIPTION
    Used where a missing object is itself a finding (a deleted group linked to a spending policy, an alert
    recipient that no longer exists), so it must be told apart from a 403 or a transient failure.
    .EXAMPLE
    if (Test-AIGovNotFoundError -ErrorRecord $_) { 'gone' }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        $ErrorRecord
    )

    $Message = [string]$ErrorRecord
    if ($ErrorRecord.Exception) { $Message = "$Message $($ErrorRecord.Exception.Message)" }
    return [bool]($Message -match '(?i)\b404\b|NotFound|Request_ResourceNotFound|does not exist')
}
