function Test-MPAIGOV1016 {
    <#
    .SYNOPSIS
    Finds MCP servers configured with weak or no authentication.
    .DESCRIPTION
    The per-package detail call, GET /copilot/admin/catalog/packages/{id}, returns an
    elementDetails array. Its elementType 'AgentConnectors' entry carries the MCP tool
    definitions: each element's definition field is a JSON string containing
    toolSource.remoteMcpServer.authorization.type -- the same JSON path MP.AIGOV.1008/1010/1011
    already read from this response, confirmed live (2026-11-06). The list-level elementTypes
    field is only used to pick candidates worth a detail call, matching on 'MCPServers' or
    'AgentConnectors': a live tenant was found (2026-11-10) with MCP-backed packages (third-party
    connector packages such as LawQi and LegalZoom) whose elementTypes carried 'AgentConnectors'
    but never the literal 'MCPServers' string, so filtering on 'MCPServers' alone silently missed
    them -- including a package that explicitly declared no authentication. A candidate without an
    actual toolSource.remoteMcpServer in its AgentConnectors definition is still skipped below and
    never counted as an MCP server.

    The documented authorization.type values (Learn: "Configure remote MCP servers for Microsoft
    365 Copilot plugins", and the root.agentConnectors.toolSource.remoteMcpServer.authorization
    schema reference) are None, OAuthPluginVault, ApiKeyPluginVault, DynamicClientRegistration,
    AzureKeyVault, and ConnectionVault (developer preview) -- not the literal strings
    "anonymous"/"shared-secret" this test's spec used as shorthand. This test reports every
    distinct value actually seen in the tenant before classifying any of them, so an unexpected
    value is visible rather than silently bucketed. Classification: the documented literal None is
    High (the manifest declares anonymous access); a missing or empty authorization object is
    Medium for a custom or external package (authentication isn't declared, so it needs a look) and
    isn't reported for a Microsoft first-party package (Microsoft's own connectors, such as the
    Dynamics 365 ones on agent365.svc.cloud.microsoft, carry no authorization block and are
    authenticated by the platform); ApiKeyPluginVault and AzureKeyVault are
    Medium (a static secret/key rather than a token-issuing identity flow -- AzureKeyVault still
    ultimately authenticates with a stored secret, it is only the secret's storage that differs);
    OAuthPluginVault and DynamicClientRegistration are a pass (an Entra/OAuth identity flow);
    ConnectionVault (developer preview) is treated as Medium pending broader documentation, the
    same conservative treatment as AzureKeyVault. An entirely missing or unparseable authorization
    object -- as opposed to a well-formed authorization object whose type is the documented literal
    "None" -- is reported separately as "Unspecified" rather than folded into the "None" bucket,
    because a missing block isn't proof the server is anonymous, and an admin reviewing the observed-values list should be able to tell a deliberately anonymous MCP
    server from one whose manifest is missing or malformed. Either Medium or High finding is reported as
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
    # not in this map at all -- anything not present here is a pass. "Unspecified" covers an
    # entirely missing/unparseable authorization object, kept distinct from the documented literal
    # "None" value so the observed-values summary doesn't conflate the two.
    $WeakAuthTypes = @{
        'None'              = 'High'
        'Unspecified'       = 'Medium'
        'ApiKeyPluginVault' = 'Medium'
        'AzureKeyVault'     = 'Medium'
        'ConnectionVault'   = 'Medium'
    }

    try {
        Write-Verbose 'Reading the Copilot package catalog for packages with MCP server elements.'
        $Packages = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri 'copilot/admin/catalog/packages' `
                -Select @('id', 'displayName', 'type', 'publisher', 'elementTypes', 'availableTo', 'deployedTo', 'isBlocked')
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

    # 'MCPServers' and 'AgentConnectors' are both used as candidate signals -- a live tenant had
    # MCP-backed packages whose elementTypes never carried the literal 'MCPServers' string, only
    # 'AgentConnectors'. A candidate here isn't yet confirmed to have an MCP server: that's decided
    # per-element below from the actual detail-call definition, and $ConfirmedMcpPackageIds tracks
    # the confirmed count for reporting.
    $AllCandidatePackages = @($Packages | Where-Object { $_.elementTypes -contains 'MCPServers' -or $_.elementTypes -contains 'AgentConnectors' })
    # Only packages users can reach are in scope: blocked packages and packages available to no one
    # are skipped, and the count is reported so the totals still add up.
    $CandidatePackages = @($AllCandidatePackages | Where-Object { Test-AIGovPackageUserAccessible -Package $_ })
    $UnreachableCount = $AllCandidatePackages.Count - $CandidatePackages.Count
    $ScopeNote = if ($UnreachableCount -gt 0) { " $UnreachableCount blocked or allowed-for-no-one package(s) skipped." } else { '' }
    Write-Verbose "Found $($AllCandidatePackages.Count) candidate package(s); $($CandidatePackages.Count) reachable by users."

    $ObservedAuthTypes = [System.Collections.Generic.HashSet[string]]::new()
    $WeakAuth = [System.Collections.Generic.List[pscustomobject]]::new()
    $ConfirmedMcpPackageIds = [System.Collections.Generic.HashSet[string]]::new()
    $FailedPackageCount = 0
    foreach ($Package in $CandidatePackages) {
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
                [void]$ConfirmedMcpPackageIds.Add($PackageId)

                $RawAuthType = [string]$RemoteMcpServer.authorization.type
                if ($null -eq $RemoteMcpServer.authorization -or [string]::IsNullOrWhiteSpace($RawAuthType)) {
                    # No authorization object at all, or a present-but-empty type -- distinct from
                    # the documented literal "None" value, which means the manifest explicitly
                    # declares anonymous access.
                    $AuthType = 'Unspecified'
                } else {
                    $AuthType = $RawAuthType
                }
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

                # Missing authorization on a Microsoft first-party package is the platform's own
                # authentication, not an anonymous server, so it isn't a finding.
                $FirstPartyUnspecified = $AuthType -eq 'Unspecified' -and -not (Test-AIGovCustomPackage -Package $Package)
                if ($WeakAuthTypes.ContainsKey($AuthType) -and -not $FirstPartyUnspecified) {
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

    if ($CandidatePackages.Count -gt 0 -and $FailedPackageCount -eq $CandidatePackages.Count) {
        Add-MtTestResultDetail -SkippedBecause Error -Result (
            "Could not evaluate any of the $($CandidatePackages.Count) candidate package(s) " +
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
            "($($ConfirmedMcpPackageIds.Count) package(s) with an MCP server element that users can reach checked).$ScopeNote $ObservedSummary"
        if ($FailedPackageCount -gt 0) {
            $Result += "`n`n$FailedPackageCount package(s) could not be evaluated (detail-read or parse error) " +
                'and are not reflected in this result.'
        }
        Add-MtTestResultDetail -Result $Result
        return $true
    }

    $HighestSeverity = if ($WeakAuth.Severity -contains 'High') { 'High' } else { 'Medium' }

    $Result = "Found $($WeakAuth.Count) MCP server(s) using weak or no authentication. $ObservedSummary"
    $Result += $ScopeNote
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
