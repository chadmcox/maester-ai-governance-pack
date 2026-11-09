function Get-AIGovClassicCopilotServicePrincipal {
    <#
    .SYNOPSIS
    Returns classic Copilot Studio service principals: tagged as agents, but not Agent ID objects.
    .DESCRIPTION
    Same tag search as MP.AIGOV.1005: AgentCreatedBy:CopilotStudio, AgenticApp, AIAgentBuilder,
    AgenticInstance, or a tag starting with power-virtual-agents-, leaving out agent identities and agent
    identity blueprint principals. Errors are left to the caller.
    .PARAMETER Select
    Service principal properties to return.
    .EXAMPLE
    Get-AIGovClassicCopilotServicePrincipal -Select id, appId, displayName, accountEnabled, createdDateTime
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $false)]
        [string[]]$Select = @('id', 'appId', 'displayName', 'tags')
    )

    $AgentIdObjectIds = @{}
    foreach ($Uri in 'servicePrincipals/microsoft.graph.agentIdentity', 'servicePrincipals/microsoft.graph.agentIdentityBlueprintPrincipal') {
        foreach ($Item in @(Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri $Uri -Select @('id'))) {
            if ($Item -and $Item.id) { $AgentIdObjectIds[[string]$Item.id] = $true }
        }
    }

    $Filters = @(
        "tags/any(t:t eq 'AgentCreatedBy:CopilotStudio')"
        "tags/any(t:t eq 'AgenticApp')"
        "tags/any(t:t eq 'AIAgentBuilder')"
        "tags/any(t:t eq 'AgenticInstance')"
        "tags/any(t:startswith(t,'power-virtual-agents-'))"
    )
    $ById = [ordered]@{}
    foreach ($Filter in $Filters) {
        foreach ($Sp in @(Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri 'servicePrincipals' -Filter $Filter -Select $Select)) {
            $Id = [string]$Sp.id
            if ([string]::IsNullOrWhiteSpace($Id) -or $AgentIdObjectIds.ContainsKey($Id)) { continue }
            $ById[$Id] = $Sp
        }
    }
    return @($ById.Values)
}
