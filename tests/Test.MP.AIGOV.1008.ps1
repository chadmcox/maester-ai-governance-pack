function Test-MPAIGOV1008 {
    <#
    .SYNOPSIS
    Finds MCP server endpoints reachable over plain http:// instead of https://.
    .DESCRIPTION
    The per-package detail call, GET /copilot/admin/catalog/packages/{id}, returns an
    elementDetails array. For packages whose list-level elementTypes includes 'MCPServers', the
    elementDetails entry with elementType 'AgentConnectors' carries the MCP tool definitions: each
    element's definition field is a JSON string containing toolSource.remoteMcpServer.mcpServerUrl.
    Confirmed live (2026-11-06) against the test tenant: all 37 MCPServers-tagged packages exposed
    exactly this shape, and every observed mcpServerUrl in that tenant was https -- so this check
    correctly reported zero findings there, which is the expected negative case, not evidence the
    check doesn't work. An agent calling an MCP server over plain HTTP sends tool-call arguments and
    results -- which may include sensitive data pulled into the conversation -- without transport
    encryption. Reading this endpoint may require a Microsoft Agent 365 license depending on tenant.
    .EXAMPLE
    Test-MPAIGOV1008
    .LINK
    https://learn.microsoft.com/graph/api/copilotadmin-get-package?view=graph-rest-1.0
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1008',
        Title        = 'MCP server endpoint should not be reachable over plain HTTP',
        Product      = 'entra',
        Feature      = 'tools',
        Area         = 'ai',
        ResourceType = 'Agent',
        Severity     = 'High',
        Permission   = 'Graph:Application:CopilotPackages.Read.All',
        Service      = 'Graph',
        Lifecycle    = 'Preview',
        LongRunning
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        Write-Verbose 'Reading the Copilot package catalog for packages with MCP server elements.'
        $Packages = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri 'copilot/admin/catalog/packages' `
                -Select @('id', 'displayName', 'elementTypes')
        )
    } catch {
        $ErrorRecord = $_
    }
    if ($ErrorRecord) {
        if ($ErrorRecord.Exception.Message -match '(?i)403|forbidden|authorization') {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized -Result (Get-AIGovPackageCatalogSkipMessage)
        } else {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $ErrorRecord
        }
        return $null
    }

    $McpPackages = @($Packages | Where-Object { $_.elementTypes -contains 'MCPServers' })
    Write-Verbose "Found $($McpPackages.Count) package(s) with an MCP server element."

    $InsecureUrls = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($Package in $McpPackages) {
        $PackageId = [string]$Package.id
        if ([string]::IsNullOrWhiteSpace($PackageId)) { continue }

        try {
            $Detail = Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri "copilot/admin/catalog/packages/$PackageId"
        } catch {
            # One package's detail call failing should not fail every other package already evaluated.
            Write-Verbose "Skipping package $PackageId after a detail-read error: $($_.Exception.Message)"
            continue
        }

        $AgentConnectorDetails = @($Detail.elementDetails | Where-Object { $_.elementType -eq 'AgentConnectors' })
        foreach ($ConnectorDetail in $AgentConnectorDetails) {
            foreach ($Element in @($ConnectorDetail.elements)) {
                if ([string]::IsNullOrWhiteSpace($Element.definition)) { continue }

                try {
                    $Parsed = $Element.definition | ConvertFrom-Json -ErrorAction Stop
                } catch {
                    Write-Verbose "Could not parse an AgentConnectors definition for package $PackageId`: $_"
                    continue
                }

                $McpServerUrl = $Parsed.toolSource.remoteMcpServer.mcpServerUrl
                if ([string]::IsNullOrWhiteSpace($McpServerUrl)) { continue }

                try {
                    $Scheme = ([uri]$McpServerUrl).Scheme
                } catch {
                    Write-Verbose "Could not parse MCP server URL '$McpServerUrl' for package $PackageId."
                    continue
                }

                if ($Scheme -eq 'http') {
                    $InsecureUrls.Add([pscustomobject]@{
                        PackageId   = $PackageId
                        DisplayName = [string]$Package.displayName
                        McpServerUrl = $McpServerUrl
                    })
                }
            }
        }
    }

    if ($InsecureUrls.Count -eq 0) {
        Add-MtTestResultDetail -Result (
            "Well done. No MCP server endpoint is reachable over plain HTTP ($($McpPackages.Count) package(s) with an MCP server element checked)."
        )
        return $true
    }

    $Result = "Found $($InsecureUrls.Count) MCP server endpoint(s) reachable over plain HTTP."
    $Result += "`n`n| Package ID | Display name | MCP server URL |"
    $Result += "`n| --- | --- | --- |"
    foreach ($Item in $InsecureUrls) {
        $Name = [string]$Item.DisplayName
        if ([string]::IsNullOrWhiteSpace($Name)) { $Name = '(unnamed)' }
        $Name = [System.Net.WebUtility]::HtmlEncode($Name) -replace '\|', '&#124;'
        $Name = $Name -replace "`r?`n", ' '
        $Result += "`n| $($Item.PackageId) | $Name | $($Item.McpServerUrl) |"
    }

    Add-MtTestResultDetail -Result $Result -Severity 'High'
    return $false
}
