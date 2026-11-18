function Get-AIGovMcpToolFingerprint {
    <#
    .SYNOPSIS
    Returns a SHA-256 fingerprint of what an MCP tool tells the model about itself.
    .DESCRIPTION
    Hashes the tool's name, description, input schema and annotations, serialized as compact JSON in
    that order. Any change to the text the model reads, to a parameter, or to a behavior hint changes
    the fingerprint. Works in Windows PowerShell 5.1 and PowerShell 7.
    .EXAMPLE
    $Tool | Get-AIGovMcpToolFingerprint
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $Tool
    )

    process {
        $Json = [ordered]@{
            name        = [string]$Tool.ToolName
            description = [string]$Tool.Description
            inputSchema = $Tool.InputSchema
            annotations = $Tool.Annotations
        } | ConvertTo-Json -Depth 20 -Compress

        $Sha = [System.Security.Cryptography.SHA256]::Create()
        try {
            $Bytes = $Sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Json))
        } finally {
            $Sha.Dispose()
        }
        ($Bytes | ForEach-Object { $_.ToString('x2') }) -join ''
    }
}
