function Test-MPAIGOV1037 {
    <#
    .SYNOPSIS
    Finds cloud agents that Microsoft Defender discovered but that have no Microsoft Entra identity.
    .DESCRIPTION
    Runs an advanced hunting query through Microsoft Graph (POST /security/runHuntingQuery, via
    Maester's Invoke-MtGraphSecurityQuery) against the AgentsInfo table, taking the latest record per
    agent and dropping deleted agents:

        AgentsInfo
        | summarize arg_max(Timestamp, *) by AgentId
        | where LifecycleStatus != "Deleted"
        | project AgentId, AgentName, Platform, EntraAgentId, EntraBlueprintId

    A cloud agent fails when both EntraAgentId and EntraBlueprintId are empty: Defender sees it, but
    it has no Entra agent identity, blueprint or enterprise application to govern with Conditional
    Access, sponsors or ID Protection. Agents with Platform 'LocalAgents' (coding agents and other
    tools found on endpoints by Defender for Endpoint) are counted separately and reported for
    information only; they don't use Entra identities.

    AgentsInfo replaced AIAgentsInfo in June 2026; the old table was readable until July 1, 2026.
    The table needs Microsoft Defender XDR with Microsoft Agent 365. Without it the query fails and the
    test skips.

    CISA/NSA "Careful Adoption of Agentic AI Services" says to keep a trusted registry of agents,
    reconcile it against live agents, and deny unregistered ones.
    .EXAMPLE
    Test-MPAIGOV1037
    .LINK
    https://learn.microsoft.com/defender-xdr/advanced-hunting-agentsinfo-table
    .LINK
    https://learn.microsoft.com/defender-xdr/security-for-ai/ai-agent-inventory
    #>
    [MaesterTest(
        Id             = 'MP.AIGOV.1037',
        Title          = 'Agents discovered by Microsoft Defender should have a Microsoft Entra identity',
        Product        = 'entra',
        RelatedProduct = 'defender',
        Feature        = 'agent-identities',
        Area           = 'ai',
        ResourceType   = 'Agent',
        Severity       = 'Medium',
        Control        = 'nist-800-53-r5:CM-8',
        Permission     = 'Graph:Application:ThreatHunting.Read.All',
        Service        = 'Graph',
        Lifecycle      = 'Preview'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $Query = @'
AgentsInfo
| summarize arg_max(Timestamp, *) by AgentId
| where LifecycleStatus != "Deleted"
| project AgentId, AgentName, Platform, EntraAgentId, EntraBlueprintId
'@

    try {
        Write-Verbose 'Querying the AgentsInfo advanced hunting table.'
        $Agents = @(Invoke-MtGraphSecurityQuery -Query $Query -Timespan 'P30D')
    } catch {
        $Message = [string]$_.Exception.Message
        if ($Message -match '(?i)403|forbidden|authorization') {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized -Result (
                "Couldn't run the advanced hunting query (403). Confirm the ThreatHunting.Read.All permission before re-running this check."
            )
        } elseif ($Message -match '(?i)AgentsInfo|failed to resolve|semantic error|table') {
            Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason (
                "The AgentsInfo advanced hunting table isn't available in this tenant. It needs Microsoft Defender XDR with Microsoft Agent 365."
            )
        } else {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        }
        return $null
    }

    $Agents = @($Agents | Where-Object { $null -ne $_ })
    $Local = @($Agents | Where-Object { [string]$_.Platform -eq 'LocalAgents' })
    $Cloud = @($Agents | Where-Object { [string]$_.Platform -ne 'LocalAgents' })
    $Unregistered = @(
        $Cloud | Where-Object {
            [string]::IsNullOrWhiteSpace([string]$_.EntraAgentId) -and [string]::IsNullOrWhiteSpace([string]$_.EntraBlueprintId)
        } | Select-Object @{ n = 'Agent'; e = { [string]$_.AgentName } },
            @{ n = 'Platform'; e = { [string]$_.Platform } },
            @{ n = 'Defender agent ID'; e = { [string]$_.AgentId } }
    )

    $LocalNote = if ($Local.Count -gt 0) {
        "`n`nFor information: Defender also found $($Local.Count) local agent(s) on endpoints (Platform 'LocalAgents'). " +
        'Review them in the Defender portal under AI assets; they are not counted as findings.'
    } else { '' }

    if ($Unregistered.Count -eq 0) {
        Add-MtTestResultDetail -Result (
            "Well done. All $($Cloud.Count) cloud agent(s) in Defender's inventory have a Microsoft Entra agent identity or blueprint.$LocalNote"
        )
        return $true
    }

    $Result = @(
        "Found $($Unregistered.Count) of $($Cloud.Count) cloud agent(s) in Defender's inventory with no Microsoft Entra agent identity or blueprint. " +
        'Register them with Microsoft Entra Agent ID, or remove them.'
        $Unregistered | Sort-Object Platform, Agent | ConvertTo-AIGovMarkdownTable -Property 'Agent', 'Platform', 'Defender agent ID'
    ) -join "`n`n"
    Add-MtTestResultDetail -Result ($Result + $LocalNote) -Severity 'Medium'
    return $false
}
