function Get-AIGovPackageKind {
    <#
    .SYNOPSIS
    Classifies a Copilot catalog package as Agent, Tool or App from its elementTypes.
    .DESCRIPTION
    Same rule as Get-PackageKind in chadmcox/Copilot "Agent and Tools Health Check", extended for the
    element types seen live (MCPServers, AgentConnectors, AgentSkills): declarativeAgent, customEngine,
    bot, AgentMetadatas (Copilot Studio agents shared in the tenant), SuperAppAgent or
    AgenticUserTemplates is an Agent; skill, connector, mcp, plugin or action is a Tool; DeclarativeCopilots
    with neither is an Agent (checked after the tool types, so an MCP package with a declarative wrapper
    stays a Tool); anything else (Office add-ins, tabs, message extensions) is an App, which the agent and
    tool checks leave out. The catalog reports declarative agents as DeclarativeCopilots, not
    DeclarativeAgent: validated against a live tenant's catalog on 2026-11-11.
    .EXAMPLE
    Get-AIGovPackageKind -ElementTypes $Package.elementTypes
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        $ElementTypes
    )

    $Text = @($ElementTypes | ForEach-Object { [string]$_ }) -join ' '
    if ($Text -match '(?i)declarativeAgent|customEngine|bot|agentMetadata|superAppAgent|agenticUserTemplate') { return 'Agent' }
    if ($Text -match '(?i)skill|connector|mcp|plugin|action') { return 'Tool' }
    if ($Text -match '(?i)declarativeCopilot') { return 'Agent' }
    return 'App'
}
