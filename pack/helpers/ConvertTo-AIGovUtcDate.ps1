function ConvertTo-AIGovUtcDate {
    <#
    .SYNOPSIS
    Converts a Graph date value to a UTC [datetime], or returns $null when it's empty or unreadable.
    .DESCRIPTION
    ConvertFrom-Json in PowerShell 7 may already have turned an ISO 8601 string into a [datetime]; older
    paths leave it as a string. Both are handled.
    .EXAMPLE
    ConvertTo-AIGovUtcDate -Value $Package.lastUsedDateTime
    #>
    [CmdletBinding()]
    [OutputType([datetime])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value) { return $null }
    if ($Value -is [datetime]) { return $Value.ToUniversalTime() }
    if ($Value -is [datetimeoffset]) { return $Value.UtcDateTime }
    $Text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
    $Parsed = [datetime]::MinValue
    $Styles = [System.Globalization.DateTimeStyles]::AdjustToUniversal -bor [System.Globalization.DateTimeStyles]::AssumeUniversal
    if ([datetime]::TryParse($Text, [System.Globalization.CultureInfo]::InvariantCulture, $Styles, [ref]$Parsed)) { return $Parsed }
    return $null
}
