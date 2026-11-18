function Test-MPAIGOV1038 {
    <#
    .SYNOPSIS
    Finds MCP tools whose definition changed, or that were added, since you last approved them.
    .DESCRIPTION
    An MCP server can change what a tool says or does after you reviewed it (a "rug pull"). This test
    reads every MCP tool in Copilot catalog packages that users can reach (blocked packages and
    packages allowed for no one are skipped, as in MP.AIGOV.1007-1016), fingerprints each tool's
    name, description, input schema and annotations with SHA-256, and compares the fingerprints with
    the baseline you approved.

    The baseline is the AIGOV.McpToolBaseline setting in maester-config.json: a list of
    { "PackageId", "ToolName", "Fingerprint" } entries. With no baseline, the test skips and prints the
    current fingerprints as JSON so you can review the tools and paste the ones you approve.

    - Changed: a tool in the baseline whose fingerprint differs. (Medium)
    - New: a tool in a reachable package that isn't in the baseline. (Medium)
    - Removed tools are listed for information only.

    CISA/NSA "Careful Adoption of Agentic AI Services" says to allow-list tools and versions and
    verify their origin and currency; the CIS Controls v8.1 MCP Companion Guide covers servers that
    change behavior after they are trusted.
    .EXAMPLE
    Test-MPAIGOV1038 -Baseline @(@{ PackageId = 'p1'; ToolName = 'search'; Fingerprint = '<sha256>' })
    .LINK
    https://learn.microsoft.com/graph/api/copilotadmin-get-package?view=graph-rest-1.0
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1038',
        Title        = 'MCP tools should match the definitions you approved',
        Product      = 'entra',
        Feature      = 'tools',
        Area         = 'ai',
        ResourceType = 'Agent',
        Severity     = 'Medium',
        Control      = 'nist-800-53-r5:CM-3',
        Permission   = 'Graph:Application:CopilotPackages.Read.All',
        Service      = 'Graph',
        Lifecycle    = 'Preview',
        LongRunning
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Approved MCP tools: objects with PackageId, ToolName and Fingerprint.
        [MaesterParameter(Setting = 'AIGOV.McpToolBaseline')]
        [object[]]$Baseline = @()
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
    $NoDefinitions = @($ToolRows | Where-Object { $_.FailureReason -eq 'ToolDefinitionsUnavailable' } | Select-Object -ExpandProperty PackageId -Unique)
    $FailedCount = @($ToolRows | Where-Object { $_.Failed -and $_.FailureReason -ne 'ToolDefinitionsUnavailable' } | Select-Object -ExpandProperty PackageId -Unique).Count

    if ($McpPackages.Count -gt 0 -and $FailedCount -eq $McpPackages.Count) {
        Add-MtTestResultDetail -SkippedBecause Error -Result "Couldn't read or parse any of the $($McpPackages.Count) package(s) with an MCP server."
        return $null
    }

    $Current = @(
        $ToolRows | Where-Object { -not $_.Failed } | Select-Object PackageId, PackageName, ToolName,
            @{ n = 'Fingerprint'; e = { $_ | Get-AIGovMcpToolFingerprint } }
    )

    # A package that lists only a server URL can't be fingerprinted. Check the rest, but never pass an incomplete check.
    $NoDefinitionsReason = (
        "$($NoDefinitions.Count) reachable package(s) list an MCP server but no tool definitions in the catalog, so their tools " +
        "can't be compared with a baseline. This check doesn't connect to MCP servers."
    )
    if ($Current.Count -eq 0 -and $NoDefinitions.Count -gt 0) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason $NoDefinitionsReason
        return $null
    }

    if (@($Baseline | Where-Object { $null -ne $_ }).Count -eq 0) {
        $Json = $Current | Select-Object PackageId, ToolName, Fingerprint | ConvertTo-Json -Depth 3
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason (
            'No MCP tool baseline is set. Review the tools, then add the approved entries to AIGOV.McpToolBaseline in maester-config.json.'
        ) -Result ("$($Current.Count) MCP tool(s) in $($McpPackages.Count) reachable package(s). Current fingerprints:`n`n``````json`n$Json`n``````" +
            $(if ($NoDefinitions.Count -gt 0) { "`n`n$NoDefinitionsReason" } else { '' }))
        return $null
    }

    $Approved = @{}
    foreach ($Entry in @($Baseline | Where-Object { $null -ne $_ })) {
        $Approved["$($Entry.PackageId)|$($Entry.ToolName)"] = [string]$Entry.Fingerprint
    }
    $Seen = @{}
    $Drift = @(
        foreach ($Tool in $Current) {
            $Key = "$($Tool.PackageId)|$($Tool.ToolName)"
            $Seen[$Key] = $true
            $Status = if (-not $Approved.ContainsKey($Key)) { 'New' } elseif ($Approved[$Key] -ne $Tool.Fingerprint) { 'Changed' }
            if ($Status) { $Tool | Select-Object @{ n = 'Package'; e = { $_.PackageName } }, @{ n = 'Tool'; e = { $_.ToolName } }, @{ n = 'Status'; e = { $Status } } }
        }
    )
    # Baseline tools in packages without definitions aren't "removed"; they just can't be seen.
    $Removed = @($Approved.Keys | Where-Object { -not $Seen.ContainsKey($_) -and ($_ -split '\|')[0] -notin $NoDefinitions })

    $Notes = @(
        if ($Removed.Count -gt 0) { "$($Removed.Count) baseline tool(s) are no longer present." }
        if ($NoDefinitions.Count -gt 0) { $NoDefinitionsReason }
        if ($FailedCount -gt 0) { "$FailedCount package(s) couldn't be read or parsed and aren't reflected in this result." }
    ) -join ' '
    if ($Notes) { $Notes = "`n`n$Notes" }

    if ($Drift.Count -eq 0 -and $NoDefinitions.Count -gt 0) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason (
            "Partial check: all $($Current.Count) MCP tool(s) that could be read match the baseline, but $NoDefinitionsReason"
        )
        return $null
    }

    if ($Drift.Count -eq 0) {
        Add-MtTestResultDetail -Result "Well done. All $($Current.Count) MCP tool(s) in reachable packages match the approved baseline.$Notes"
        return $true
    }

    $Result = @(
        "Found $($Drift.Count) MCP tool(s) that changed or were added since the baseline was approved. Review each tool's definition before re-approving it."
        $Drift | Sort-Object Status, Package, Tool | ConvertTo-AIGovMarkdownTable -Property 'Package', 'Tool', 'Status'
    ) -join "`n`n"
    Add-MtTestResultDetail -Result ($Result + $Notes) -Severity 'Medium'
    return $false
}
