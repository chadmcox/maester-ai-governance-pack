function Test-MPAIGOV1052 {
    <#
    .SYNOPSIS
    Finds agents that Microsoft Defender flags with an active exposure risk at or above a set severity.
    .DESCRIPTION
    Runs an advanced hunting query through Microsoft Graph (Invoke-MtGraphSecurityQuery) against the
    AgentsInfo table, takes the latest record per agent, and expands its RiskIndicators column. Each
    indicator is Defender's own assessment of an agent, with a title (such as "Running on a Device with
    Vulnerabilities" or "Dormant agent"), a severity, and flags for whether it is active and whether it is
    an exposure.

    An agent fails when it isn't deleted, uninstalled or blocked and has at least one active exposure
    indicator at or above AIGOV.MinAgentRiskSeverity (default Medium). Blast-radius indicators such as
    "Connection count" carry no severity and aren't counted. Vendor agents from the Microsoft 365 agent
    catalog (platform Other, no owners, no source agent ID) and platforms in AIGOV.ExcludedAgentPlatforms
    are left out, as in MP.AIGOV.1037. Local agents that Defender for Endpoint found on devices are
    included, because their indicators describe the device they run on.

    The table needs Microsoft Defender XDR with Microsoft Agent 365. Without it the test skips.
    .PARAMETER MinSeverity
    The lowest indicator severity that fails the test: High, Medium or Low.
    .EXAMPLE
    Test-MPAIGOV1052
    .LINK
    https://learn.microsoft.com/defender-xdr/advanced-hunting-agentsinfo-table
    .LINK
    https://learn.microsoft.com/defender-xdr/security-for-ai/ai-agent-inventory
    #>
    [MaesterTest(
        Id             = 'MP.AIGOV.1052',
        Title          = 'Agents should not have active risk indicators in Microsoft Defender',
        Product        = 'entra',
        RelatedProduct = 'defender',
        Feature        = 'agent-identities',
        Area           = 'ai',
        ResourceType   = 'Agent',
        Severity       = 'Medium',
        Control        = 'nist-800-53-r5:RA-5',
        Permission     = 'Graph:Application:ThreatHunting.Read.All',
        Service        = 'Graph',
        Lifecycle      = 'Preview'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [MaesterParameter(Setting = 'AIGOV.MinAgentRiskSeverity')]
        [ValidateSet('High', 'Medium', 'Low')]
        [string]$MinSeverity = 'Medium',

        [MaesterParameter(Setting = 'AIGOV.ExcludedAgentPlatforms')]
        [string[]]$ExcludedPlatforms = @()
    )

    # RiskIndicators is a property bag keyed by indicator ID; kind=array turns each entry into [key, value].
    # 'title' is a KQL keyword, so the indicator's properties are read with brackets.
    $Query = @'
AgentsInfo
| summarize arg_max(Timestamp, *) by AgentId
| extend AgentName_ = tostring(column_ifexists("AgentName", column_ifexists("Name", ""))),
    LifecycleStatus_ = tostring(column_ifexists("LifecycleStatus", "")),
    PublishedStatus_ = tostring(column_ifexists("PublishedStatus", "")),
    Owners_ = tostring(column_ifexists("Owners", "")),
    SourceAgentId_ = tostring(column_ifexists("SourceAgentId", "")),
    Risk_ = todynamic(column_ifexists("RiskIndicators", dynamic(null)))
| where LifecycleStatus_ !in~ ("Deleted", "Uninstalled", "Blocked")
| mv-expand kind=array Risk = Risk_
| extend Indicator = todynamic(Risk[1])
| where isnotempty(tostring(Indicator['title'])) and tobool(Indicator['isActive']) == true and tobool(Indicator['isExposure']) == true
| project AgentId, AgentName = AgentName_, Platform, PublishedStatus = PublishedStatus_,
    HasOwners = Owners_ !in ("", "[]", "{}", "null"), HasSourceId = isnotempty(SourceAgentId_),
    Title = tostring(Indicator['title']), Severity = tostring(Indicator['severity'])
'@

    try {
        Write-Verbose 'Querying AgentsInfo risk indicators.'
        $Indicators = @(Invoke-MtGraphSecurityQuery -Query $Query -Timespan 'P30D' | Where-Object { $null -ne $_ })
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

    $Rank = @{ 'Low' = 1; 'Medium' = 2; 'High' = 3 }
    $Floor = $Rank[$MinSeverity]
    $InScope = @(
        $Indicators | Where-Object {
            -not ([string]$_.Platform -eq 'Other' -and -not ($_.HasOwners -eq $true) -and -not ($_.HasSourceId -eq $true)) -and
            [string]$_.Platform -notin $ExcludedPlatforms
        }
    )
    $Findings = @($InScope | Where-Object { $Rank[[string]$_.Severity] -ge $Floor })
    $Below = $InScope.Count - $Findings.Count

    if ($Findings.Count -eq 0) {
        $Result = "Well done. No agent has an active Defender risk indicator at $MinSeverity severity or above."
        if ($Below -gt 0) { $Result = "$Result $Below lower-severity indicator(s) were not counted." }
        Add-MtTestResultDetail -Result $Result
        return $true
    }

    $Agents = @($Findings | Select-Object -ExpandProperty AgentId -Unique).Count
    $Result = @(
        "Found $Agents agent(s) with $($Findings.Count) active Defender risk indicator(s) at $MinSeverity severity or above. Open each agent in the Defender portal (Assets > AI agents) for the evidence and the related recommendations."
        $Findings | Sort-Object { -$Rank[[string]$_.Severity] }, AgentName, Title |
            Select-Object @{ n = 'Agent'; e = { [string]$_.AgentName } }, Platform, @{ n = 'Risk'; e = { [string]$_.Title } }, Severity, @{ n = 'Defender agent ID'; e = { [string]$_.AgentId } } |
            ConvertTo-AIGovMarkdownTable -Property 'Agent', 'Platform', 'Risk', 'Severity', 'Defender agent ID'
        if ($Below -gt 0) { "$Below lower-severity indicator(s) were not counted (AIGOV.MinAgentRiskSeverity is $MinSeverity)." }
    ) -join "`n`n"
    Add-MtTestResultDetail -Result $Result -Severity 'Medium'
    return $false
}
