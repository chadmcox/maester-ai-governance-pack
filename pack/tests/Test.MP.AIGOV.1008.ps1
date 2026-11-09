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
        Control      = 'nist-800-53-r5:SC-8',
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
                -Select @('id', 'displayName', 'elementTypes', 'availableTo', 'isBlocked')
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

    $AllMcpPackages = @($Packages | Where-Object { $_.elementTypes -contains 'MCPServers' })
    # Only packages users can reach are in scope: blocked packages and packages available to no one
    # are skipped, and the count is reported so the totals still add up.
    $McpPackages = @($AllMcpPackages | Where-Object { Test-AIGovPackageUserAccessible -Package $_ })
    $UnreachableCount = $AllMcpPackages.Count - $McpPackages.Count
    $ScopeNote = if ($UnreachableCount -gt 0) { " $UnreachableCount blocked or allowed-for-no-one package(s) skipped." } else { '' }
    Write-Verbose "Found $($AllMcpPackages.Count) package(s) with an MCP server element; $($McpPackages.Count) reachable by users."

    $InsecureUrls = [System.Collections.Generic.List[pscustomobject]]::new()
    $FailedPackageCount = 0
    foreach ($Package in $McpPackages) {
        $PackageId = [string]$Package.id
        if ([string]::IsNullOrWhiteSpace($PackageId)) { continue }

        try {
            $Detail = Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri "copilot/admin/catalog/packages/$PackageId"
        } catch {
            # One package's detail call failing should not fail every other package already evaluated,
            # but it must be counted so a silent gap in coverage is never reported as a clean pass.
            Write-Verbose "Skipping package $PackageId after a detail-read error: $($_.Exception.Message)"
            $FailedPackageCount++
            continue
        }

        $AgentConnectorDetails = @($Detail.elementDetails | Where-Object { $_.elementType -eq 'AgentConnectors' })
        $PackageHadParseFailure = $false
        foreach ($ConnectorDetail in $AgentConnectorDetails) {
            foreach ($Element in @($ConnectorDetail.elements)) {
                if ([string]::IsNullOrWhiteSpace($Element.definition)) { continue }

                try {
                    $Parsed = $Element.definition | ConvertFrom-Json -ErrorAction Stop
                } catch {
                    Write-Verbose "Could not parse an AgentConnectors definition for package $PackageId`: $_"
                    $PackageHadParseFailure = $true
                    continue
                }

                $McpServerUrl = $Parsed.toolSource.remoteMcpServer.mcpServerUrl
                if ([string]::IsNullOrWhiteSpace($McpServerUrl)) { continue }

                try {
                    $Uri = [uri]$McpServerUrl
                } catch {
                    Write-Verbose "Could not parse MCP server URL for package $PackageId."
                    $PackageHadParseFailure = $true
                    continue
                }

                if ($Uri.Scheme -eq 'http') {
                    $InsecureUrls.Add([pscustomobject]@{
                        PackageId   = $PackageId
                        DisplayName = [string]$Package.displayName
                        # Report scheme + host only: the full URL (path/query/fragment/userinfo)
                        # is never surfaced, since it may carry tenant- or tool-specific identifiers.
                        SchemeHost  = "$($Uri.Scheme)://$($Uri.Authority)"
                    })
                }
            }
        }
        if ($PackageHadParseFailure) { $FailedPackageCount++ }
    }

    if ($McpPackages.Count -gt 0 -and $FailedPackageCount -eq $McpPackages.Count) {
        Add-MtTestResultDetail -SkippedBecause Error -Result (
            "Could not evaluate any of the $($McpPackages.Count) package(s) with an MCP server element " +
            "-- every detail call or definition parse failed. See verbose logs for details."
        )
        return $null
    }

    if ($InsecureUrls.Count -eq 0) {
        $Result = "Well done. No MCP server endpoint is reachable over plain HTTP " +
            "($($McpPackages.Count) package(s) with an MCP server element that users can reach checked).$ScopeNote"
        if ($FailedPackageCount -gt 0) {
            $Result += "`n`n$FailedPackageCount package(s) could not be evaluated (detail-read or parse error) " +
                'and are not reflected in this result.'
        }
        Add-MtTestResultDetail -Result $Result
        return $true
    }

    $Result = "Found $($InsecureUrls.Count) MCP server endpoint(s) reachable over plain HTTP."
    $Result += $ScopeNote
    if ($FailedPackageCount -gt 0) {
        $Result += " $FailedPackageCount package(s) could not be evaluated (detail-read or parse error) " +
            'and are not reflected below.'
    }
    $Result += "`n`n| Package ID | Display name | MCP server host |"
    $Result += "`n| --- | --- | --- |"
    foreach ($Item in $InsecureUrls) {
        $Name = [string]$Item.DisplayName
        if ([string]::IsNullOrWhiteSpace($Name)) { $Name = '(unnamed)' }
        $Name = [System.Net.WebUtility]::HtmlEncode($Name) -replace '\|', '&#124;'
        $Name = $Name -replace "`r?`n", ' '
        $SchemeHost = [System.Net.WebUtility]::HtmlEncode([string]$Item.SchemeHost) -replace '\|', '&#124;'
        $Result += "`n| $($Item.PackageId) | $Name | $SchemeHost |"
    }

    Add-MtTestResultDetail -Result $Result -Severity 'High'
    return $false
}
