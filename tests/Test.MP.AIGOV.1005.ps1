function Test-MPAIGOV1005 {
    <#
    .SYNOPSIS
    Finds classic Copilot Studio service principals with no corresponding Agent ID registration.
    .DESCRIPTION
    Identifies service principals tagged as Copilot Studio agents (AgentCreatedBy:CopilotStudio,
    AgenticApp, AIAgentBuilder, AgenticInstance, or a power-virtual-agents-* tag) that are not
    themselves Agent Identities or Agent Identity Blueprint Principals. This describes a state, not a
    migration path: Microsoft has not published an in-place way to convert a classic service principal
    into an Agent ID. Tag-based, not a cross-reference against a separate bot list. Graph only, no
    Agent 365 license required.
    .EXAMPLE
    Test-MPAIGOV1005
    .LINK
    https://learn.microsoft.com/graph/api/serviceprincipal-list?view=graph-rest-1.0
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1005',
        Title        = 'Classic Copilot Studio service principal has no corresponding Agent ID registration (Preview)',
        Product      = 'entra',
        Feature      = 'agents-without-agent-id',
        Area         = 'ai',
        ResourceType = 'Agent',
        Severity     = 'Info',
        Permission   = 'Graph:Application:Application.Read.All',
        Service      = 'Graph',
        Lifecycle    = 'Preview'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        Write-Verbose 'Reading Agent Identities and Blueprint Principals to exclude them from the classic tag search.'
        $AgentIdObjectIds = @{}
        @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri 'servicePrincipals/microsoft.graph.agentIdentity' -Select @('id')
        ) | ForEach-Object { $AgentIdObjectIds[[string]$_.id] = $true }
        @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri 'servicePrincipals/microsoft.graph.agentIdentityBlueprintPrincipal' -Select @('id')
        ) | ForEach-Object { $AgentIdObjectIds[[string]$_.id] = $true }

        # Each tag filter is a separate call; servicePrincipals does not support a single 'any of these
        # tags' filter. Results are merged and de-duplicated by object ID below.
        #
        # No ConsistencyLevel/$count=true needed here: per Microsoft Learn's advanced-queries
        # reference (https://learn.microsoft.com/en-us/graph/aad-advanced-queries, servicePrincipal
        # properties table), tags/any(p:p) supports both eq and startsWith as "Default+Advanced",
        # meaning both already work without the advanced query parameters.
        $TagFilters = @(
            "tags/any(t:t eq 'AgentCreatedBy:CopilotStudio')"
            "tags/any(t:t eq 'AgenticApp')"
            "tags/any(t:t eq 'AIAgentBuilder')"
            "tags/any(t:t eq 'AgenticInstance')"
            "tags/any(t:startswith(t,'power-virtual-agents-'))"
        )

        $ClassicAgents = @{}
        foreach ($TagFilter in $TagFilters) {
            $TaggedSps = @(
                Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri 'servicePrincipals' `
                    -Filter $TagFilter -Select @('id', 'appId', 'displayName', 'tags')
            )
            foreach ($Match in $TaggedSps) {
                $ObjectId = [string]$Match.id
                if ([string]::IsNullOrWhiteSpace($ObjectId)) { continue }
                if ($AgentIdObjectIds.ContainsKey($ObjectId)) { continue }
                $ClassicAgents[$ObjectId] = $Match
            }
        }

        Write-Verbose "Found $($ClassicAgents.Count) classic Copilot Studio service principal(s) without an Agent ID registration."

        if ($ClassicAgents.Count -eq 0) {
            Add-MtTestResultDetail -Result (
                'Well done. No classic Copilot Studio service principals were found without a corresponding Agent ID registration.'
            )
            return $true
        }

        $Result = "Found $($ClassicAgents.Count) classic Copilot Studio service principal(s) with no Agent ID registration."
        $Result += "`n`nThis describes a current state, not a required migration: Microsoft has not published an in-place way to convert these."
        $Result += "`n`n| Object ID | App ID | Display name |"
        $Result += "`n| --- | --- | --- |"
        foreach ($Agent in $ClassicAgents.Values) {
            $DisplayName = [string]$Agent.displayName
            if ([string]::IsNullOrWhiteSpace($DisplayName)) { $DisplayName = '(unnamed)' }
            $DisplayName = [System.Net.WebUtility]::HtmlEncode($DisplayName) -replace '\|', '&#124;'
            $DisplayName = $DisplayName -replace "`r?`n", ' '
            $Result += "`n| $([string]$Agent.id) | $([string]$Agent.appId) | $DisplayName |"
        }

        Add-MtTestResultDetail -Result $Result -Severity 'Info'
        return $false
    } catch {
        $ErrorRecord = $_
    }

    if ($ErrorRecord.Exception.Message -match '(?i)403|forbidden|authorization') {
        Add-MtTestResultDetail -SkippedBecause NotAuthorized
    } else {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $ErrorRecord
    }
    return $null
}
