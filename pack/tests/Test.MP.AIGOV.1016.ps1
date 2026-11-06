function Test-MPAIGOV1016 {
    <#
    .SYNOPSIS
    Finds MCP servers configured with weak or no authentication.
    .DESCRIPTION
    The per-package detail call, GET /copilot/admin/catalog/packages/{id}, returns an
    elementDetails array. For packages whose list-level elementTypes includes 'MCPServers', the
    elementDetails entry with elementType 'AgentConnectors' carries the MCP tool definitions: each
    element's definition field is a JSON string containing
    toolSource.remoteMcpServer.authorization.type -- the same JSON path MP.AIGOV.1008/1010/1011
    already read from this response, confirmed live (2026-11-06).

    The documented authorization.type values (Learn: "Configure remote MCP servers for Microsoft
    365 Copilot plugins", and the root.agentConnectors.toolSource.remoteMcpServer.authorization
    schema reference) are None, OAuthPluginVault, ApiKeyPluginVault, DynamicClientRegistration,
    AzureKeyVault, and ConnectionVault (developer preview) -- not the literal strings
    "anonymous"/"shared-secret" this test's spec used as shorthand. This test reports every
    distinct value actually seen in the tenant before classifying any of them, so an unexpected
    value is visible rather than silently bucketed. Classification: None or a missing/unparseable
    authorization.type is High (no authentication at all); ApiKeyPluginVault and AzureKeyVault are
    Medium (a static secret/key rather than a token-issuing identity flow -- AzureKeyVault still
    ultimately authenticates with a stored secret, it is only the secret's storage that differs);
    OAuthPluginVault and DynamicClientRegistration are a pass (an Entra/OAuth identity flow);
    ConnectionVault (developer preview) is treated as Medium pending broader documentation, the
    same conservative treatment as AzureKeyVault. Either Medium or High finding is reported as
    worse when the package is tenant-wide, using the same availableTo/deployedTo signal as
    MP.AIGOV.1007/1011. Only the MCP server's scheme and host are ever reported -- never the full
    mcpServerUrl, matching MP.AIGOV.1008. Reading this endpoint may require a Microsoft Agent 365
    license depending on tenant.
    .EXAMPLE
    Test-MPAIGOV1016
    .LINK
    https://learn.microsoft.com/microsoft-365/copilot/extensibility/configure-plugin-mcp-servers
    .LINK
    https://learn.microsoft.com/graph/api/copilotadmin-get-package?view=graph-rest-1.0
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1016',
        Title        = 'MCP server should not use weak or no authentication',
        Product      = 'entra',
        Feature      = 'tools',
        Area         = 'ai',
        ResourceType = 'Agent',
        Severity     = 'High',
        Control      = 'nist-800-53-r5:IA-2',
        Permission   = 'Graph:Application:CopilotPackages.Read.All',
        Service      = 'Graph',
        Lifecycle    = 'Preview',
        LongRunning
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # None/missing = no authentication at all. ApiKeyPluginVault/AzureKeyVault = a static secret,
    # not a token-issuing identity flow. ConnectionVault is developer preview and treated the same
    # as AzureKeyVault pending broader documentation. OAuthPluginVault/DynamicClientRegistration are
    # not in this map at all -- anything not present here is a pass.
    $WeakAuthTypes = @{
        'None'              = 'High'
        'ApiKeyPluginVault' = 'Medium'
        'AzureKeyVault'     = 'Medium'
        'ConnectionVault'   = 'Medium'
    }

    try {
        Write-Verbose 'Reading the Copilot package catalog for packages with MCP server elements.'
        $Packages = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri 'copilot/admin/catalog/packages' `
                -Select @('id', 'displayName', 'elementTypes', 'availableTo', 'deployedTo')
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

    $ObservedAuthTypes = [System.Collections.Generic.HashSet[string]]::new()
    $WeakAuth = [System.Collections.Generic.List[pscustomobject]]::new()
    $FailedPackageCount = 0
    foreach ($Package in $McpPackages) {
        $PackageId = [string]$Package.id
        if ([string]::IsNullOrWhiteSpace($PackageId)) { continue }

        $IsTenantWide = ([string]$Package.availableTo -match '(?i)allowedForAll') -or
            ([string]$Package.deployedTo -match '(?i)acquiredForAll')

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

                $RemoteMcpServer = $Parsed.toolSource.remoteMcpServer
                if ($null -eq $RemoteMcpServer) { continue }

                $AuthType = [string]$RemoteMcpServer.authorization.type
                if ([string]::IsNullOrWhiteSpace($AuthType)) { $AuthType = 'None' }
                [void]$ObservedAuthTypes.Add($AuthType)

                $SchemeHost = $null
                if (-not [string]::IsNullOrWhiteSpace([string]$RemoteMcpServer.mcpServerUrl)) {
                    try {
                        $Uri = [uri]$RemoteMcpServer.mcpServerUrl
                        $SchemeHost = "$($Uri.Scheme)://$($Uri.Authority)"
                    } catch {
                        Write-Verbose "Could not parse MCP server URL for package $PackageId."
                    }
                }

                if ($WeakAuthTypes.ContainsKey($AuthType)) {
                    $WeakAuth.Add([pscustomobject]@{
                        PackageId    = $PackageId
                        DisplayName  = [string]$Package.displayName
                        SchemeHost   = if ($SchemeHost) { $SchemeHost } else { '(unknown)' }
                        AuthType     = $AuthType
                        Severity     = $WeakAuthTypes[$AuthType]
                        IsTenantWide = $IsTenantWide
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

    $ObservedSummary = if ($ObservedAuthTypes.Count -gt 0) {
        "Distinct authorization.type value(s) observed: $(($ObservedAuthTypes | Sort-Object) -join ', ')."
    } else {
        'No MCP server carried a parseable authorization.type.'
    }

    if ($WeakAuth.Count -eq 0) {
        $Result = "Well done. No MCP server uses weak or no authentication " +
            "($($McpPackages.Count) package(s) with an MCP server element checked). $ObservedSummary"
        if ($FailedPackageCount -gt 0) {
            $Result += "`n`n$FailedPackageCount package(s) could not be evaluated (detail-read or parse error) " +
                'and are not reflected in this result.'
        }
        Add-MtTestResultDetail -Result $Result
        return $true
    }

    $HighestSeverity = if ($WeakAuth.Severity -contains 'High') { 'High' } else { 'Medium' }

    $Result = "Found $($WeakAuth.Count) MCP server(s) using weak or no authentication. $ObservedSummary"
    if ($FailedPackageCount -gt 0) {
        $Result += " $FailedPackageCount package(s) could not be evaluated (detail-read or parse error) " +
            'and are not reflected below.'
    }
    $Result += "`n`n| Package ID | Display name | MCP server host | Authorization type | Severity | Tenant-wide |"
    $Result += "`n| --- | --- | --- | --- | --- | --- |"
    foreach ($Item in $WeakAuth) {
        $Name = [string]$Item.DisplayName
        if ([string]::IsNullOrWhiteSpace($Name)) { $Name = '(unnamed)' }
        $Name = [System.Net.WebUtility]::HtmlEncode($Name) -replace '\|', '&#124;'
        $Name = $Name -replace "`r?`n", ' '
        $SchemeHost = [System.Net.WebUtility]::HtmlEncode([string]$Item.SchemeHost) -replace '\|', '&#124;'
        $TenantWideText = if ($Item.IsTenantWide) { 'Yes' } else { 'No' }
        $Result += "`n| $($Item.PackageId) | $Name | $SchemeHost | $($Item.AuthType) | $($Item.Severity) | $TenantWideText |"
    }

    Add-MtTestResultDetail -Result $Result -Severity $HighestSeverity
    return $false
}
