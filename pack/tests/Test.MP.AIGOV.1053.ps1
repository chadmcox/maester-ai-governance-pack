function Test-MPAIGOV1053 {
    <#
    .SYNOPSIS
    Checks the MCP servers that Microsoft Defender finds on agents: HTTPS, an allowlisted host, and approval on published agents.
    .DESCRIPTION
    Runs an advanced hunting query through Microsoft Graph (Invoke-MtGraphSecurityQuery) against the
    AgentsInfo table, takes the latest record per agent, and expands its McpServers column. That covers
    MCP servers MP.AIGOV.1008 and 1010 can't see because they aren't in the Copilot agent catalog: MCP
    servers configured in Copilot Studio agents, and in local agents such as GitHub Copilot CLI or Claude
    Code that Defender for Endpoint found on devices.

    An MCP server on an agent that isn't deleted, uninstalled or blocked fails when:

    - its endpoint uses plain HTTP instead of HTTPS;
    - its endpoint host isn't on the allowlist (an exact match or a subdomain of an entry); or
    - it's on a published agent and runs its tools without asking (approvalModeKind always_allow).

    MCP servers with no endpoint, such as Copilot Studio servers reached through a Power Platform
    connector, are only checked for approval. The report shows the scheme and host only, never the full URL.
    The table needs Microsoft Defender XDR with Microsoft Agent 365. Without it the test skips.
    .PARAMETER AllowedHosts
    Host suffixes treated as trusted, as in MP.AIGOV.1010, plus cloud.microsoft.
    .EXAMPLE
    Test-MPAIGOV1053
    .LINK
    https://learn.microsoft.com/defender-xdr/advanced-hunting-agentsinfo-table
    .LINK
    https://learn.microsoft.com/microsoft-copilot-studio/mcp-add-existing-server-to-agent
    #>
    [MaesterTest(
        Id             = 'MP.AIGOV.1053',
        Title          = 'MCP servers on agents found by Microsoft Defender should use HTTPS, trusted hosts and approval',
        Product        = 'entra',
        RelatedProduct = 'defender',
        Feature        = 'agent-identities',
        Area           = 'ai',
        ResourceType   = 'Agent',
        Severity       = 'Medium',
        Control        = 'nist-800-53-r5:SC-8',
        Permission     = 'Graph:Application:ThreatHunting.Read.All',
        Service        = 'Graph',
        Lifecycle      = 'Preview'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [string[]]$AllowedHosts = @(
            'microsoft.com', 'microsoftonline.com', 'azure.com', 'azurewebsites.net',
            'dynamics.com', 'powerplatform.com', 'powerapps.com', 'powerbi.com',
            'office.com', 'office365.com', 'sharepoint.com', 'windows.net',
            'msidentity.com', 'visualstudio.com', 'cloud.microsoft'
        )
    )

    # McpServers holds JSON strings; todynamic(tostring()) parses them whether stored as text or objects.
    $Query = @'
AgentsInfo
| summarize arg_max(Timestamp, *) by AgentId
| extend AgentName_ = tostring(column_ifexists("AgentName", column_ifexists("Name", ""))),
    LifecycleStatus_ = tostring(column_ifexists("LifecycleStatus", "")),
    PublishedStatus_ = tostring(column_ifexists("PublishedStatus", "")),
    Mcp_ = todynamic(column_ifexists("McpServers", dynamic(null)))
| where LifecycleStatus_ !in~ ("Deleted", "Uninstalled", "Blocked")
| mv-expand Mcp = Mcp_
| extend Server = todynamic(tostring(Mcp))
| where isnotempty(tostring(Server.name))
| project AgentId, AgentName = AgentName_, Platform, PublishedStatus = PublishedStatus_,
    McpName = tostring(Server.name), McpType = tostring(Server.type), Endpoint = tostring(Server.endpoint),
    Approval = tostring(Server.approvalModeKind)
'@

    try {
        Write-Verbose 'Querying AgentsInfo MCP servers.'
        $Servers = @(Invoke-MtGraphSecurityQuery -Query $Query -Timespan 'P30D' | Where-Object { $null -ne $_ })
    } catch {
        $Message = [string]$_.Exception.Message
        if ($Message -match '(?i)403|forbidden|authorization') {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized -Result (
                "Couldn't run the advanced hunting query (403). Confirm the ThreatHunting.Read.All permission before re-running this check."
            )
        } elseif ($Message -match '(?i)failed to resolve table' -and $Message -match "['""]AgentsInfo['""]") {
            Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason (
                "The AgentsInfo advanced hunting table isn't available in this tenant. It needs Microsoft Defender XDR with Microsoft Agent 365."
            )
        } else {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        }
        return $null
    }

    if ($Servers.Count -eq 0) {
        Add-MtTestResultDetail -Result 'Defender reports no MCP servers on agents that are in use.'
        return $true
    }

    $Checked = @(
        $Servers | Select-Object @{ n = 'Agent'; e = { [string]$_.AgentName } }, Platform, PublishedStatus,
            @{ n = 'MCP server'; e = { [string]$_.McpName } },
            @{ n = 'Uri'; e = { $Endpoint = [string]$_.Endpoint; if ($Endpoint) { try { [uri]$Endpoint } catch { $null } } } },
            Approval |
            Select-Object Agent, Platform, 'MCP server',
                @{ n = 'Endpoint'; e = { if ($_.Uri) { "$($_.Uri.Scheme)://$($_.Uri.Authority)" } else { '(none)' } } },
                @{ n = 'Reason'; e = {
                        $HostName = if ($_.Uri) { $_.Uri.Host }
                        @(
                            if ($_.Uri -and $_.Uri.Scheme -eq 'http') { 'plain HTTP' }
                            if ($HostName -and -not @($AllowedHosts | Where-Object { $_ -and ($HostName -eq $_ -or $HostName.EndsWith(".$_", [System.StringComparison]::OrdinalIgnoreCase)) })) { 'host not on the allowlist' }
                            if ([string]$_.PublishedStatus -eq 'Published' -and [string]$_.Approval -eq 'always_allow') { 'runs tools without asking on a published agent' }
                        ) -join '; '
                    }
                }
    )
    $Findings = @($Checked | Where-Object Reason)

    if ($Findings.Count -eq 0) {
        Add-MtTestResultDetail -Result "Well done. All $($Checked.Count) MCP server(s) Defender found on agents in use meet the rules."
        return $true
    }

    $Result = @(
        "Found $($Findings.Count) of $($Checked.Count) MCP server(s) on agents in use that break an MCP rule."
        $Findings | Sort-Object Agent, 'MCP server' | ConvertTo-AIGovMarkdownTable -Property 'Agent', 'Platform', 'MCP server', 'Endpoint', 'Reason'
    ) -join "`n`n"
    Add-MtTestResultDetail -Result $Result -Severity 'Medium'
    return $false
}
