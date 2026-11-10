function Test-MPAIGOV1010 {
    <#
    .SYNOPSIS
    Finds MCP server endpoints hosted on a domain not on the configured allowlist.
    .DESCRIPTION
    The per-package detail call, GET /copilot/admin/catalog/packages/{id}, returns an
    elementDetails array. For packages whose list-level elementTypes includes 'MCPServers' or 'AgentConnectors', the
    elementDetails entry with elementType 'AgentConnectors' carries the MCP tool definitions: each
    element's definition field is a JSON string containing toolSource.remoteMcpServer.mcpServerUrl.
    This test checks the URL's host against a configurable allowlist (-AllowedHosts), matched as an
    exact host or any subdomain of an allowlisted suffix. The default allowlist covers common
    Microsoft domains only; live validation against the test tenant (2026-11-06) found 37 packages
    with an MCP server element, spanning 36 distinct third-party hosts (for example mcp.asana.com,
    mcp.factset.com, mcp.xero.com) and zero Microsoft-hosted ones -- so with the default allowlist
    this check currently flags all 37 in that tenant. That is the expected starting state, not a
    bug: the allowlist is meant to be curated per tenant as vendors are reviewed and approved, after
    which only genuinely new or unreviewed hosts should surface. An MCP server hosted somewhere
    outside the reviewed set is a supply-chain exposure that broader tool-review findings (like
    MP.AIGOV.1011) don't catch on their own. Reading this endpoint may require a Microsoft Agent 365
    license depending on tenant.
    .EXAMPLE
    Test-MPAIGOV1010
    .EXAMPLE
    Test-MPAIGOV1010 -AllowedHosts @('microsoft.com', 'asana.com', 'factset.com')
    .LINK
    https://learn.microsoft.com/graph/api/copilotadmin-get-package?view=graph-rest-1.0
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1010',
        Title        = 'MCP server should be hosted on an allowlisted domain',
        Product      = 'entra',
        Feature      = 'tools',
        Area         = 'ai',
        ResourceType = 'Agent',
        Severity     = 'Medium',
        Control      = 'nist-800-53-r5:SA-9',
        Permission   = 'Graph:Application:CopilotPackages.Read.All',
        Service      = 'Graph',
        Lifecycle    = 'Preview',
        LongRunning
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Host suffixes treated as trusted. An MCP server host matches if it equals an entry exactly
        # or is a subdomain of one. Defaults to common Microsoft domains only; override with your
        # tenant's reviewed/approved vendor hosts as they are onboarded.
        [Parameter(Mandatory = $false)]
        [string[]]$AllowedHosts = @(
            'microsoft.com', 'microsoftonline.com', 'azure.com', 'azurewebsites.net',
            'dynamics.com', 'powerplatform.com', 'powerapps.com', 'powerbi.com',
            'office.com', 'office365.com', 'sharepoint.com', 'windows.net',
            'msidentity.com', 'visualstudio.com'
        )
    )

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

    # 'AgentConnectors' too: some MCP-backed packages never list 'MCPServers' (found live 2026-11-10).
    # Elements without toolSource.remoteMcpServer are skipped when the definitions are read below.
    $AllMcpPackages = @($Packages | Where-Object { $_.elementTypes -contains 'MCPServers' -or $_.elementTypes -contains 'AgentConnectors' })
    # Only packages users can reach are in scope: blocked packages and packages available to no one
    # are skipped, and the count is reported so the totals still add up.
    $McpPackages = @($AllMcpPackages | Where-Object { Test-AIGovPackageUserAccessible -Package $_ })
    $UnreachableCount = $AllMcpPackages.Count - $McpPackages.Count
    $ScopeNote = if ($UnreachableCount -gt 0) { " $UnreachableCount blocked or allowed-for-no-one package(s) skipped." } else { '' }
    Write-Verbose "Found $($AllMcpPackages.Count) package(s) with an MCP server or agent connector element; $($McpPackages.Count) reachable by users."

    $NonAllowlisted = [System.Collections.Generic.List[pscustomobject]]::new()
    $FailedPackageCount = 0
    foreach ($Package in $McpPackages) {
        $PackageId = [string]$Package.id
        if ([string]::IsNullOrWhiteSpace($PackageId)) { continue }

        try {
            $Detail = Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri "copilot/admin/catalog/packages/$PackageId"
        } catch {
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

                $HostName = $Uri.Host
                $IsAllowed = $false
                foreach ($Allowed in $AllowedHosts) {
                    if ([string]::IsNullOrWhiteSpace($Allowed)) { continue }
                    if ($HostName -eq $Allowed -or $HostName.EndsWith(".$Allowed", [System.StringComparison]::OrdinalIgnoreCase)) {
                        $IsAllowed = $true
                        break
                    }
                }

                if (-not $IsAllowed) {
                    $NonAllowlisted.Add([pscustomobject]@{
                        PackageId   = $PackageId
                        DisplayName = [string]$Package.displayName
                        # Report scheme + host only, never the full URL -- same redaction as MP.AIGOV.1008.
                        SchemeHost  = "$($Uri.Scheme)://$($Uri.Authority)"
                    })
                }
            }
        }
        if ($PackageHadParseFailure) { $FailedPackageCount++ }
    }

    if ($McpPackages.Count -gt 0 -and $FailedPackageCount -eq $McpPackages.Count) {
        Add-MtTestResultDetail -SkippedBecause Error -Result (
            "Could not evaluate any of the $($McpPackages.Count) package(s) with an MCP server or agent connector element " +
            "-- every detail call or definition parse failed. See verbose logs for details."
        )
        return $null
    }

    if ($NonAllowlisted.Count -eq 0) {
        $Result = "Well done. Every MCP server endpoint is hosted on an allowlisted domain " +
            "($($McpPackages.Count) package(s) with an MCP server or agent connector element that users can reach checked).$ScopeNote"
        if ($FailedPackageCount -gt 0) {
            $Result += "`n`n$FailedPackageCount package(s) could not be evaluated (detail-read or parse error) " +
                'and are not reflected in this result.'
        }
        Add-MtTestResultDetail -Result $Result
        return $true
    }

    $Result = "Found $($NonAllowlisted.Count) MCP server endpoint(s) hosted on a domain not on the configured allowlist."
    $Result += $ScopeNote
    if ($FailedPackageCount -gt 0) {
        $Result += " $FailedPackageCount package(s) could not be evaluated (detail-read or parse error) " +
            'and are not reflected below.'
    }
    $Result += "`n`n| Package ID | Display name | MCP server host |"
    $Result += "`n| --- | --- | --- |"
    foreach ($Item in $NonAllowlisted) {
        $Name = [string]$Item.DisplayName
        if ([string]::IsNullOrWhiteSpace($Name)) { $Name = '(unnamed)' }
        $Name = [System.Net.WebUtility]::HtmlEncode($Name) -replace '\|', '&#124;'
        $Name = $Name -replace "`r?`n", ' '
        $SchemeHost = [System.Net.WebUtility]::HtmlEncode([string]$Item.SchemeHost) -replace '\|', '&#124;'
        $Result += "`n| $($Item.PackageId) | $Name | $SchemeHost |"
    }

    Add-MtTestResultDetail -Result $Result -Severity 'Medium'
    return $false
}
