function Get-AIGovPackageKind {
    <#
    .SYNOPSIS
    Classifies a Copilot catalog package as Agent, Tool or App from its elementTypes.
    .DESCRIPTION
    Same rule as Get-PackageKind in chadmcox/Copilot "Agent and Tools Health Check", extended for the
    element types seen live (MCPServers, AgentConnectors, AgentSkills): declarativeAgent, customEngine or
    bot is an Agent; skill, connector, mcp, plugin or action is a Tool; anything else (Office add-ins,
    tabs) is an App, which the agent and tool checks leave out.
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
    if ($Text -match '(?i)declarativeAgent|customEngine|bot') { return 'Agent' }
    if ($Text -match '(?i)skill|connector|mcp|plugin|action') { return 'Tool' }
    return 'App'
}
