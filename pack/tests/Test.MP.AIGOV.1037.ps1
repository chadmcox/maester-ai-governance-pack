function Test-MPAIGOV1037 {
    <#
    .SYNOPSIS
    Finds cloud agents that Microsoft Defender discovered but that have no Microsoft Entra identity.
    .DESCRIPTION
    Runs an advanced hunting query through Microsoft Graph (POST /security/runHuntingQuery, via
    Maester's Invoke-MtGraphSecurityQuery) against the AgentsInfo table and takes the latest record per
    agent. It keeps only agents that are live: LifecycleStatus not Deleted, Uninstalled or Blocked,
    and PublishedStatus not Draft. Drafts are counted for information.

    Column names differ between the AgentsInfo documentation (AgentName, EntraAgentId,
    EntraBlueprintId) and some live tenants (Name, EntraAgentID, EntraBlueprintID). The query reads
    whichever exists with column_ifexists.

    A live cloud agent fails when both its Entra agent ID and blueprint ID are empty: Defender sees it,
    but it has no Entra agent identity, blueprint or enterprise application to govern with
    Conditional Access, sponsors or ID Protection.

    Agents on platform 'Other' with no owners and no source agent ID are vendor agents from the
    Microsoft 365 agent catalog (store apps such as declarative agents). They run inside Copilot, are
    governed through the catalog, and don't get an Entra agent identity, so they're counted for
    information only. Vendor agents that act on their own, such as Frontier agents, do have one.

    Some platforms list agents that run as the signed-in user and never get an Entra agent identity
    by design. The result always includes a count by Platform. After reviewing it, list those
    platforms in the AIGOV.ExcludedAgentPlatforms setting; their agents are then counted for
    information only. Agents with Platform 'LocalAgents' (tools Defender for Endpoint found on
    devices) are always reported for information only.

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
    param(
        # Defender platforms whose agents run as the signed-in user and never get an Entra agent identity.
        [MaesterParameter(Setting = 'AIGOV.ExcludedAgentPlatforms')]
        [string[]]$ExcludedPlatforms = @(),

        # The most agent rows to list in the result table.
        [ValidateRange(1, 1000)]
        [int]$MaxRows = 100
    )

    $Query = @'
AgentsInfo
| summarize arg_max(Timestamp, *) by AgentId
| extend AgentName_ = tostring(column_ifexists("AgentName", column_ifexists("Name", ""))),
    EntraAgentId_ = tostring(column_ifexists("EntraAgentId", column_ifexists("EntraAgentID", ""))),
    EntraBlueprintId_ = tostring(column_ifexists("EntraBlueprintId", column_ifexists("EntraBlueprintID", ""))),
    LifecycleStatus_ = tostring(column_ifexists("LifecycleStatus", "")),
    PublishedStatus_ = tostring(column_ifexists("PublishedStatus", "")),
    Owners_ = tostring(column_ifexists("Owners", "")),
    SourceAgentId_ = tostring(column_ifexists("SourceAgentId", ""))
| where LifecycleStatus_ !in~ ("Deleted", "Uninstalled", "Blocked")
| project AgentId, AgentName = AgentName_, Platform, EntraAgentId = EntraAgentId_, EntraBlueprintId = EntraBlueprintId_, PublishedStatus = PublishedStatus_,
    HasOwners = Owners_ !in ("", "[]", "{}", "null"), HasSourceId = isnotempty(SourceAgentId_)
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
        } elseif ($Message -match '(?i)failed to resolve table' -and $Message -match "['""]AgentsInfo['""]") {
            Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason (
                "The AgentsInfo advanced hunting table isn't available in this tenant. It needs Microsoft Defender XDR with Microsoft Agent 365."
            )
        } else {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        }
        return $null
    }

    $Agents = @($Agents | Where-Object { $null -ne $_ })
    $Rows = @(
        $Agents | Select-Object AgentId, AgentName, Platform, PublishedStatus,
            @{ n = 'HasEntra'; e = { -not ([string]::IsNullOrWhiteSpace([string]$_.EntraAgentId) -and [string]::IsNullOrWhiteSpace([string]$_.EntraBlueprintId)) } },
            @{ n = 'Scope'; e = {
                    if ([string]$_.Platform -eq 'LocalAgents') { 'Local' }
                    elseif ([string]$_.Platform -in $ExcludedPlatforms) { 'Excluded' }
                    elseif ([string]$_.PublishedStatus -eq 'Draft') { 'Draft' }
                    elseif ([string]$_.Platform -eq 'Other' -and -not ($_.HasOwners -eq $true) -and -not ($_.HasSourceId -eq $true)) { 'Catalog' }
                    else { 'InScope' }
                }
            }
    )
    $InScope = @($Rows | Where-Object { $_.Scope -eq 'InScope' })
    $Unregistered = @(
        $InScope | Where-Object { -not $_.HasEntra } |
            Select-Object @{ n = 'Agent'; e = { [string]$_.AgentName } }, Platform, @{ n = 'Defender agent ID'; e = { [string]$_.AgentId } }
    )

    # Count by platform so an admin can tell unregistered agents from platforms that never use Entra identities.
    $ByPlatform = @(
        $Rows | Group-Object -Property { if ([string]::IsNullOrWhiteSpace([string]$_.Platform)) { '(none)' } else { [string]$_.Platform } } |
            Sort-Object -Property Count -Descending |
            Select-Object @{ n = 'Platform'; e = { $_.Name } },
                @{ n = 'Agents'; e = { $_.Count } },
                @{ n = 'Drafts'; e = { @($_.Group | Where-Object { [string]$_.PublishedStatus -eq 'Draft' }).Count } },
                @{ n = 'Counted'; e = { @($_.Group | Where-Object { $_.Scope -eq 'InScope' }).Count } },
                @{ n = 'Counted, no Entra identity'; e = { @($_.Group | Where-Object { $_.Scope -eq 'InScope' -and -not $_.HasEntra }).Count } },
                @{ n = 'All, no Entra identity'; e = { @($_.Group | Where-Object { -not $_.HasEntra }).Count } },
                @{ n = 'Platform status'; e = {
                        $Scopes = @($_.Group | Select-Object -ExpandProperty Scope -Unique)
                        if ($Scopes -contains 'Local') { 'No (local agents)' }
                        elseif ($Scopes -contains 'Excluded') { 'No (excluded platform)' }
                        elseif ($Scopes -contains 'InScope') { 'Counted' }
                        elseif ($Scopes -contains 'Catalog') { 'No (vendor catalog agents)' }
                        else { 'No (drafts only)' }
                    }
                }
    )
    $PlatformTable = $ByPlatform | ConvertTo-AIGovMarkdownTable -Property 'Platform', 'Agents', 'Drafts', 'Counted', 'Counted, no Entra identity', 'All, no Entra identity', 'Platform status'

    $Info = @(
        $Count = @($Rows | Where-Object { $_.Scope -eq 'Local' }).Count
        if ($Count -gt 0) { "$Count local agent(s) on endpoints (Platform 'LocalAgents') are listed for information; review them in the Defender portal under AI assets." }
        $Count = @($Rows | Where-Object { $_.Scope -eq 'Draft' }).Count
        if ($Count -gt 0) { "$Count draft agent(s) aren't counted until they're published." }
        $Count = @($Rows | Where-Object { $_.Scope -eq 'Catalog' }).Count
        if ($Count -gt 0) { "$Count vendor agent(s) from the Microsoft 365 agent catalog (platform 'Other', no owners or source agent ID) aren't counted; govern them in the catalog (MP.AIGOV.1007)." }
        $Count = @($Rows | Where-Object { $_.Scope -eq 'Excluded' }).Count
        if ($Count -gt 0) { "$Count agent(s) on excluded platforms ($($ExcludedPlatforms -join ', ')) aren't counted." }
    ) -join ' '
    $Footer = $(if ($Rows.Count -gt 0) { "`n`nAgents by platform:`n`n$PlatformTable" } else { '' }) + $(if ($Info) { "`n`n$Info" } else { '' })

    if ($InScope.Count -eq 0) {
        Add-MtTestResultDetail -Result "Well done. Defender's inventory has no published cloud agents that need a Microsoft Entra agent identity.$Footer"
        return $true
    }

    if ($Unregistered.Count -eq 0) {
        Add-MtTestResultDetail -Result (
            "Well done. All $($InScope.Count) live cloud agent(s) in Defender's inventory have a Microsoft Entra agent identity or blueprint.$Footer"
        )
        return $true
    }

    $Listed = @($Unregistered | Sort-Object Platform, Agent | Select-Object -First $MaxRows)
    $More = if ($Unregistered.Count -gt $MaxRows) { "`n`n...and $($Unregistered.Count - $MaxRows) more." } else { '' }
    $Result = @(
        "Found $($Unregistered.Count) of $($InScope.Count) live cloud agent(s) in Defender's inventory with no Microsoft Entra agent identity or blueprint. " +
        'Check the platform counts below first: if a platform runs every agent as the signed-in user, add it to AIGOV.ExcludedAgentPlatforms. ' +
        'Register the rest with Microsoft Entra Agent ID, or remove them.'
        ($Listed | ConvertTo-AIGovMarkdownTable -Property 'Agent', 'Platform', 'Defender agent ID') + $More
    ) -join "`n`n"
    Add-MtTestResultDetail -Result ($Result + $Footer) -Severity 'Medium'
    return $false
}
