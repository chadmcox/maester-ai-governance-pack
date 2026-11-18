function ConvertTo-AIGovMarkdownTable {
    <#
    .SYNOPSIS
    Turns objects into a markdown table for a Maester result.
    .DESCRIPTION
    Writes one header row from -Property, then one row per piped object. Every cell goes through
    ConvertTo-AIGovMarkdownCell, so tenant data can't break the table or inject markup. Shape the
    objects first with Select-Object calculated properties; the property names become the headers.
    .EXAMPLE
    $Rows | Select-Object @{ n = 'Display name'; e = { $_.displayName } } |
        ConvertTo-AIGovMarkdownTable -Property 'Display name'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [AllowNull()]
        $InputObject,

        [Parameter(Mandatory = $true)]
        [string[]]$Property
    )

    begin {
        $Rows = [System.Collections.Generic.List[string]]::new()
    }
    process {
        foreach ($Item in @($InputObject)) {
            if ($null -eq $Item) { continue }
            $Cells = foreach ($Name in $Property) { ConvertTo-AIGovMarkdownCell -Text $Item.$Name }
            $Rows.Add('| ' + ($Cells -join ' | ') + ' |')
        }
    }
    end {
        @(
            '| ' + ($Property -join ' | ') + ' |'
            '| ' + (($Property | ForEach-Object { '---' }) -join ' | ') + ' |'
            $Rows
        ) -join "`n"
    }
}
