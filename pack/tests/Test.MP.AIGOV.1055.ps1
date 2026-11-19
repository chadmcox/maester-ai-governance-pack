function Test-MPAIGOV1055 {
    <#
    .SYNOPSIS
    Finds local AI agents on devices that act without asking the user, or that run in an untrusted host process.
    .DESCRIPTION
    Runs an advanced hunting query through Microsoft Graph (Invoke-MtGraphSecurityQuery) against the
    AgentsInfo table for local AI agents (Platform LocalAgents) that Microsoft Defender for Endpoint found
    on devices, such as coding agents and desktop AI apps. It takes the latest record per agent and reads
    RawAgentInfo.localAgentMetadata, as in Microsoft's documented query:

    - autoApprove "true": the agent runs tools and reaches resources without a person confirming each step.
    - trustedProcess "false": the process hosting the agent isn't trusted.

    An agent that isn't deleted or uninstalled fails (Medium) when either is true. Both values are strings.
    Discovery needs Microsoft Defender for Endpoint Plan 2 on onboarded Windows or macOS devices. Without the
    AgentsInfo table the test skips; with no local agents it passes.
    .EXAMPLE
    Test-MPAIGOV1055
    .LINK
    https://learn.microsoft.com/defender-endpoint/discover-local-ai-agents
    #>
    [MaesterTest(
        Id             = 'MP.AIGOV.1055',
        Title          = 'Local AI agents should ask before acting and run in a trusted process',
        Product        = 'entra',
        RelatedProduct = 'defender',
        Feature        = 'agent-identities',
        Area           = 'ai',
        ResourceType   = 'Agent',
        Severity       = 'Medium',
        Control        = 'nist-800-53-r5:CM-7',
        Permission     = 'Graph:Application:ThreatHunting.Read.All',
        Service        = 'Graph',
        Lifecycle      = 'Preview'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $Query = @'
AgentsInfo
| where Platform == "LocalAgents"
| summarize arg_max(Timestamp, Name, Version, LifecycleStatus, RawAgentInfo) by AgentId
| where LifecycleStatus !in~ ("Deleted", "Uninstalled")
| extend Meta = todynamic(RawAgentInfo).localAgentMetadata
| project AgentId, Agent = Name, Version,
    Vendor = tostring(Meta.vendor), Process = tostring(Meta.relatedProcess),
    Device = tostring(Meta.deviceName), Account = tostring(Meta.accountName),
    AutoApprove = tostring(Meta.autoApprove), TrustedProcess = tostring(Meta.trustedProcess)
'@

    try {
        Write-Verbose 'Querying AgentsInfo for local AI agents.'
        $Agents = @(Invoke-MtGraphSecurityQuery -Query $Query -Timespan 'P30D' | Where-Object { $null -ne $_ })
    } catch {
        $Message = [string]$_.Exception.Message
        if ($Message -match '(?i)403|forbidden|authorization') {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized -Result (
                "Couldn't run the advanced hunting query (403). Confirm the ThreatHunting.Read.All permission before re-running this check."
            )
        } elseif ($Message -match '(?i)failed to resolve table' -and $Message -match "['""]AgentsInfo['""]") {
            Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason (
                "The AgentsInfo advanced hunting table isn't available in this tenant. Local AI agent discovery needs Microsoft Defender for Endpoint Plan 2."
            )
        } else {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        }
        return $null
    }

    if ($Agents.Count -eq 0) {
        Add-MtTestResultDetail -Result 'Defender reports no local AI agents on devices.'
        return $true
    }

    $Findings = @(
        $Agents | Where-Object { [string]$_.AutoApprove -eq 'true' -or [string]$_.TrustedProcess -eq 'false' } |
            Select-Object Agent, Vendor, Version, Device, Account,
                @{ n = 'Reason'; e = {
                        @(
                            if ([string]$_.AutoApprove -eq 'true') { 'acts without asking' }
                            if ([string]$_.TrustedProcess -eq 'false') { "host process isn't trusted" }
                        ) -join '; '
                    }
                }
    )
    $Unknown = @($Agents | Where-Object { [string]::IsNullOrWhiteSpace($_.AutoApprove) -and [string]::IsNullOrWhiteSpace($_.TrustedProcess) }).Count
    $Note = if ($Unknown -gt 0) { "$Unknown local agent(s) reported neither setting and weren't judged." }

    if ($Findings.Count -eq 0) {
        Add-MtTestResultDetail -Result (@("Well done. None of the $($Agents.Count) local AI agent(s) acts without asking or runs in an untrusted process.", $Note | Where-Object { $_ }) -join "`n`n")
        return $true
    }

    $Result = (@(
            "Found $($Findings.Count) of $($Agents.Count) local AI agent(s) that act without asking the user or run in an untrusted process."
            $Findings | Sort-Object Device, Agent | ConvertTo-AIGovMarkdownTable -Property 'Agent', 'Vendor', 'Version', 'Device', 'Account', 'Reason'
            $Note
        ) | Where-Object { $_ }) -join "`n`n"
    Add-MtTestResultDetail -Result $Result -Severity 'Medium'
    return $false
}
