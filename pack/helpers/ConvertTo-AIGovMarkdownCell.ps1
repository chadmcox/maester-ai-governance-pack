function ConvertTo-AIGovMarkdownCell {
    <#
    .SYNOPSIS
    Makes a value safe to put in a markdown table cell in a Maester result.
    .DESCRIPTION
    HTML-encodes the text, escapes the pipe character, and collapses line breaks to spaces, so tenant
    data (display names, policy names) can't break the table or inject markup.
    .EXAMPLE
    ConvertTo-AIGovMarkdownCell -Text $Group.displayName
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [AllowEmptyString()]
        $Text
    )

    $Encoded = [System.Net.WebUtility]::HtmlEncode([string]$Text) -replace '\|', '&#124;'
    return ($Encoded -replace "`r?`n", ' ')
}
