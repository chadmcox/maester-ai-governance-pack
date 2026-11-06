function Test-MPAIGOV1011 {
    <#
    .SYNOPSIS
    Finds MCP tools with a destructive or open-world effect inside a package available or deployed
    tenant-wide.
    .DESCRIPTION
    Combines two independently-confirmed signals from the Copilot package catalog. The tenant-wide
    signal is the same one MP.AIGOV.1007 uses: availableTo indicating allowedForAll, or deployedTo
    indicating acquiredForAll. The tool-risk signal comes from the per-package detail call, GET
    /copilot/admin/catalog/packages/{id}: for packages whose elementTypes includes 'MCPServers', the
    elementDetails entry with elementType 'AgentConnectors' carries
    toolSource.remoteMcpServer.mcpToolDescription.tools[], each with an annotations object
    (destructiveHint, openWorldHint, readOnlyHint, idempotentHint) -- confirmed live (2026-11-06)
    against the test tenant. A tool flagged destructiveHint=true can make an irreversible change; one
    flagged openWorldHint=true can interact with an open-ended, not-fully-enumerable set of external
    entities. Either property, combined with the tool being reachable by everyone in the tenant by
    default, is a materially different risk than the same tool scoped to a reviewed pilot group.
    MP.AIGOV.1007 flags tenant-wide custom packages generally; this test narrows to the subset whose
    MCP tools themselves carry a documented high-impact annotation. Reading this endpoint may require
    a Microsoft Agent 365 license depending on tenant.
    .EXAMPLE
    Test-MPAIGOV1011
    .LINK
    https://learn.microsoft.com/graph/api/copilotadmin-get-package?view=graph-rest-1.0
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1011',
        Title        = 'MCP tool with a destructive or open-world effect should not be in a tenant-wide package',
        Product      = 'entra',
        Feature      = 'tools',
        Area         = 'ai',
        ResourceType = 'Agent',
        Severity     = 'High',
        Control      = 'nist-800-53-r5:AC-6',
        Permission   = 'Graph:Application:CopilotPackages.Read.All',
        Service      = 'Graph',
        Lifecycle    = 'Preview',
        LongRunning
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        Write-Verbose 'Reading the Copilot package catalog for tenant-wide packages with MCP server elements.'
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

    $TenantWideMcpPackages = @($Packages | Where-Object {
        ($_.elementTypes -contains 'MCPServers') -and
        (([string]$_.availableTo -match '(?i)allowedForAll') -or ([string]$_.deployedTo -match '(?i)acquiredForAll'))
    })
    Write-Verbose "Found $($TenantWideMcpPackages.Count) tenant-wide package(s) with an MCP server element."

    $RiskyTools = [System.Collections.Generic.List[pscustomobject]]::new()
    $FailedPackageCount = 0
    foreach ($Package in $TenantWideMcpPackages) {
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

                $Tools = @($Parsed.toolSource.remoteMcpServer.mcpToolDescription.tools)
                foreach ($Tool in $Tools) {
                    $IsDestructive = $Tool.annotations.destructiveHint -eq $true
                    $IsOpenWorld = $Tool.annotations.openWorldHint -eq $true
                    if (-not ($IsDestructive -or $IsOpenWorld)) { continue }

                    $Reasons = [System.Collections.Generic.List[string]]::new()
                    if ($IsDestructive) { $Reasons.Add('destructiveHint') }
                    if ($IsOpenWorld) { $Reasons.Add('openWorldHint') }

                    $RiskyTools.Add([pscustomobject]@{
                        PackageId   = $PackageId
                        DisplayName = [string]$Package.displayName
                        ToolName    = [string]$Tool.name
                        Reasons     = ($Reasons -join ', ')
                    })
                }
            }
        }
        if ($PackageHadParseFailure) { $FailedPackageCount++ }
    }

    if ($TenantWideMcpPackages.Count -gt 0 -and $FailedPackageCount -eq $TenantWideMcpPackages.Count) {
        Add-MtTestResultDetail -SkippedBecause Error -Result (
            "Could not evaluate any of the $($TenantWideMcpPackages.Count) tenant-wide package(s) with an MCP " +
            "server element -- every detail call or definition parse failed. See verbose logs for details."
        )
        return $null
    }

    if ($RiskyTools.Count -eq 0) {
        $Result = "Well done. No MCP tool with a destructive or open-world effect was found in a tenant-wide " +
            "package ($($TenantWideMcpPackages.Count) tenant-wide package(s) with an MCP server element checked)."
        if ($FailedPackageCount -gt 0) {
            $Result += "`n`n$FailedPackageCount package(s) could not be evaluated (detail-read or parse error) " +
                'and are not reflected in this result.'
        }
        Add-MtTestResultDetail -Result $Result
        return $true
    }

    $Result = "Found $($RiskyTools.Count) MCP tool(s) with a destructive or open-world effect in a tenant-wide package."
    if ($FailedPackageCount -gt 0) {
        $Result += " $FailedPackageCount package(s) could not be evaluated (detail-read or parse error) " +
            'and are not reflected below.'
    }
    $Result += "`n`n| Package ID | Display name | Tool name | Annotation(s) |"
    $Result += "`n| --- | --- | --- | --- |"
    foreach ($Item in $RiskyTools) {
        $Name = [string]$Item.DisplayName
        if ([string]::IsNullOrWhiteSpace($Name)) { $Name = '(unnamed)' }
        $Name = [System.Net.WebUtility]::HtmlEncode($Name) -replace '\|', '&#124;'
        $Name = $Name -replace "`r?`n", ' '
        $ToolName = [string]$Item.ToolName
        if ([string]::IsNullOrWhiteSpace($ToolName)) { $ToolName = '(unnamed)' }
        $ToolName = [System.Net.WebUtility]::HtmlEncode($ToolName) -replace '\|', '&#124;'
        $ToolName = $ToolName -replace "`r?`n", ' '
        $Result += "`n| $($Item.PackageId) | $Name | $ToolName | $($Item.Reasons) |"
    }

    Add-MtTestResultDetail -Result $Result -Severity 'High'
    return $false
}
