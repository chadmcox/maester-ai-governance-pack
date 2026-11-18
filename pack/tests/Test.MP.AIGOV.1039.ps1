function Test-MPAIGOV1039 {
    <#
    .SYNOPSIS
    Finds MCP tools whose description tries to steer the model, or that carry no behavior annotations.
    .DESCRIPTION
    Reads every MCP tool in Copilot catalog packages that users can reach (blocked packages and
    packages allowed for no one are skipped, as in MP.AIGOV.1007-1016) and checks two things:

    - Steering text (Medium): the tool's description, or any text in its input schema, matches a
      pattern that reads like an instruction to the model rather than a description of the tool, such
      as "ignore previous instructions", "always call this tool", "do not tell the user", or a request
      to send credentials. This is the tool-poisoning pattern. Tune the patterns with the
      AIGOV.McpSteeringPatterns setting.
    - No annotations (Low): the tool sets none of readOnlyHint, destructiveHint, idempotentHint or
      openWorldHint, so MP.AIGOV.1011 and reviewers can't tell what it does.

    CISA/NSA "Careful Adoption of Agentic AI Services" says to standardize tool descriptions, avoid
    persuasive language in them, and validate tool selection and responses.
    .EXAMPLE
    Test-MPAIGOV1039
    .LINK
    https://learn.microsoft.com/graph/api/copilotadmin-get-package?view=graph-rest-1.0
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1039',
        Title        = 'MCP tool descriptions should describe the tool, not instruct the model',
        Product      = 'entra',
        Feature      = 'tools',
        Area         = 'ai',
        ResourceType = 'Agent',
        Severity     = 'Medium',
        Control      = 'nist-800-53-r5:SI-10',
        Permission   = 'Graph:Application:CopilotPackages.Read.All',
        Service      = 'Graph',
        Lifecycle    = 'Preview',
        LongRunning
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Regular expressions that mark a tool description as trying to steer the model.
        [MaesterParameter(Setting = 'AIGOV.McpSteeringPatterns')]
        [string[]]$SteeringPatterns = @(
            '(?i)ignore\s+(all\s+|any\s+)?(previous|prior|above|other)\s+(instructions|prompts|rules)',
            '(?i)disregard\s+(the\s+|all\s+)?(system|previous|prior|above)',
            '(?i)do\s+not\s+(tell|inform|mention|reveal|show)\b.{0,30}\buser',
            '(?i)always\s+(call|use|invoke|run|prefer)\s+this\s+tool',
            '(?i)(before|instead\s+of)\s+(using|calling)\s+(any|other|all)\s+(other\s+)?tools?',
            '(?i)<\s*/?\s*(important|system|instructions?)\s*>',
            '(?i)you\s+must\s+(always|first|now|never)',
            '(?i)(send|forward|upload|post|include)\b.{0,40}\b(credential|password|token|secret|api\s*key)s?\b'
        )
    )

    try {
        Write-Verbose 'Reading the Copilot package catalog for packages with MCP servers.'
        $Packages = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri 'copilot/admin/catalog/packages' `
                -Select @('id', 'displayName', 'elementTypes', 'availableTo', 'isBlocked')
        )
    } catch {
        if ($_.Exception.Message -match '(?i)403|forbidden|authorization') {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized -Result (Get-AIGovPackageCatalogSkipMessage)
        } else {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        }
        return $null
    }

    $McpPackages = @($Packages | Where-Object {
            ($_.elementTypes -contains 'MCPServers' -or $_.elementTypes -contains 'AgentConnectors') -and
            (Test-AIGovPackageUserAccessible -Package $_)
        })
    $ToolRows = @($McpPackages | Get-AIGovMcpTool)
    $FailedCount = @($ToolRows | Where-Object { $_.Failed } | Select-Object -ExpandProperty PackageId -Unique).Count
    $Tools = @($ToolRows | Where-Object { -not $_.Failed })

    if ($McpPackages.Count -gt 0 -and $FailedCount -eq $McpPackages.Count) {
        Add-MtTestResultDetail -SkippedBecause Error -Result "Couldn't read or parse any of the $($McpPackages.Count) package(s) with an MCP server."
        return $null
    }

    $HintNames = 'readOnlyHint', 'destructiveHint', 'idempotentHint', 'openWorldHint'
    $Findings = @(
        foreach ($Tool in $Tools) {
            $Text = "$($Tool.Description) $($Tool.InputSchema | ConvertTo-Json -Depth 20 -Compress)"
            $Matched = @(
                foreach ($Pattern in $SteeringPatterns) {
                    $Match = [regex]::Match($Text, $Pattern)
                    if ($Match.Success) { $Match.Value }
                }
            )
            $HasHint = @($HintNames | Where-Object { $null -ne $Tool.Annotations -and $null -ne $Tool.Annotations.$_ }).Count -gt 0
            $Issue = if ($Matched.Count -gt 0) { 'Steering text' } elseif (-not $HasHint) { 'No annotations' }
            if ($Issue) {
                $Tool | Select-Object @{ n = 'Package'; e = { $_.PackageName } }, @{ n = 'Tool'; e = { $_.ToolName } },
                    @{ n = 'Issue'; e = { $Issue } },
                    @{ n = 'Matched text'; e = { ($Matched | Select-Object -First 2) -join ' / ' } }
            }
        }
    )

    $Note = if ($FailedCount -gt 0) { "`n`n$FailedCount package(s) couldn't be read or parsed and aren't reflected in this result." } else { '' }

    if ($Findings.Count -eq 0) {
        Add-MtTestResultDetail -Result "Well done. All $($Tools.Count) MCP tool(s) in reachable packages have plain descriptions and behavior annotations.$Note"
        return $true
    }

    $Steering = @($Findings | Where-Object { $_.Issue -eq 'Steering text' })
    $Severity = if ($Steering.Count -gt 0) { 'Medium' } else { 'Low' }
    $Result = @(
        "Found $($Steering.Count) MCP tool(s) with steering text and $($Findings.Count - $Steering.Count) with no behavior annotations."
        $Findings | Sort-Object Issue, Package, Tool | ConvertTo-AIGovMarkdownTable -Property 'Package', 'Tool', 'Issue', 'Matched text'
    ) -join "`n`n"
    Add-MtTestResultDetail -Result ($Result + $Note) -Severity $Severity
    return $false
}
