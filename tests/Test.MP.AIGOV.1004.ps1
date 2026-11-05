function Test-MPAIGOV1004 {
    <#
    .SYNOPSIS
    Finds Agent Identities, Agent Identity Blueprints, and Blueprint Principals with exactly one
    sponsor and zero owners.
    .DESCRIPTION
    A sponsor is organizational accountability; an owner can administer the object itself (rotate
    credentials, change permissions, delete it). An object with exactly one sponsor and no owners has
    a single point of failure: if that one sponsor leaves or is disabled, nobody with a formal
    relationship to the object remains. Graph only, no Agent 365 license required. Uses the same
    per-object sponsor-collection shape as MT.1205; run it against your tenant to confirm.
    .EXAMPLE
    Test-MPAIGOV1004
    .LINK
    https://learn.microsoft.com/graph/api/agentidentityblueprint-list-sponsors?view=graph-rest-1.0
    .LINK
    https://learn.microsoft.com/graph/api/serviceprincipal-list-owners?view=graph-rest-1.0
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1004',
        Title        = 'Agent identity, blueprint, or blueprint principal has exactly one sponsor and zero owners (Preview)',
        Product      = 'entra',
        Feature      = 'agent-identities',
        Area         = 'ai',
        ResourceType = 'Agent',
        Severity     = 'Low',
        Control      = 'nist-800-53-r5:AC-2',
        Permission   = 'Graph:Application:Application.Read.All|Graph:Delegated:Directory.Read.All',
        Service      = 'Graph',
        Lifecycle    = 'Preview'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        Write-Verbose 'Reading Agent Identities, Blueprints, and Blueprint Principals for sponsor/owner checks.'
        $Identities = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                -RelativeUri 'servicePrincipals/microsoft.graph.agentIdentity' `
                -Select @('id', 'displayName', 'appId')
        )
        $BlueprintPrincipals = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                -RelativeUri 'servicePrincipals/microsoft.graph.agentIdentityBlueprintPrincipal' `
                -Select @('id', 'displayName', 'appId')
        )
        $Blueprints = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                -RelativeUri 'applications/microsoft.graph.agentIdentityBlueprint' `
                -Select @('id', 'displayName', 'appId')
        )

        # Each object type exposes sponsors/owners under its own collection endpoint (servicePrincipals
        # for identities and blueprint principals, applications for blueprints). Same per-object call
        # shape MT.1205 already uses; the engine turns an uncaught 403 here into the catch block below.
        $Objects = [System.Collections.Generic.List[pscustomobject]]::new()
        foreach ($Identity in $Identities) {
            $Objects.Add([pscustomobject]@{
                ObjectId      = [string]$Identity.id
                DisplayName   = [string]$Identity.displayName
                ObjectType    = 'Agent Identity'
                SponsorsUri   = "servicePrincipals/$($Identity.id)/microsoft.graph.agentIdentity/sponsors"
                OwnersUri     = "servicePrincipals/$($Identity.id)/owners"
            })
        }
        foreach ($BlueprintPrincipal in $BlueprintPrincipals) {
            $Objects.Add([pscustomobject]@{
                ObjectId      = [string]$BlueprintPrincipal.id
                DisplayName   = [string]$BlueprintPrincipal.displayName
                ObjectType    = 'Blueprint Principal'
                SponsorsUri   = "servicePrincipals/$($BlueprintPrincipal.id)/microsoft.graph.agentIdentityBlueprintPrincipal/sponsors"
                OwnersUri     = "servicePrincipals/$($BlueprintPrincipal.id)/owners"
            })
        }
        foreach ($Blueprint in $Blueprints) {
            $Objects.Add([pscustomobject]@{
                ObjectId      = [string]$Blueprint.id
                DisplayName   = [string]$Blueprint.displayName
                ObjectType    = 'Agent Blueprint'
                SponsorsUri   = "applications/$($Blueprint.id)/microsoft.graph.agentIdentityBlueprint/sponsors"
                OwnersUri     = "applications/$($Blueprint.id)/owners"
            })
        }

        Write-Verbose "Evaluating sponsor/owner counts for $($Objects.Count) Agent ID object(s)."

        $SinglePointOfFailure = [System.Collections.Generic.List[pscustomobject]]::new()
        foreach ($Object in $Objects) {
            if ([string]::IsNullOrWhiteSpace($Object.ObjectId)) { continue }

            $Sponsors = @(Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri $Object.SponsorsUri -Select @('id'))
            $Owners = @(Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri $Object.OwnersUri -Select @('id'))

            if ($Sponsors.Count -eq 1 -and $Owners.Count -eq 0) {
                $SinglePointOfFailure.Add([pscustomobject]@{
                    ObjectId    = $Object.ObjectId
                    DisplayName = $Object.DisplayName
                    ObjectType  = $Object.ObjectType
                })
            }
        }

        if ($SinglePointOfFailure.Count -eq 0) {
            Add-MtTestResultDetail -Result (
                'Well done. No Agent ID object has exactly one sponsor and zero owners.'
            )
            return $true
        }

        $Result = "Found $($SinglePointOfFailure.Count) Agent ID object(s) with exactly one sponsor and zero owners."
        $Result += "`n`n| Object ID | Display name | Object type |"
        $Result += "`n| --- | --- | --- |"
        foreach ($Item in $SinglePointOfFailure) {
            $DisplayName = [string]$Item.DisplayName
            if ([string]::IsNullOrWhiteSpace($DisplayName)) { $DisplayName = '(unnamed)' }
            $DisplayName = [System.Net.WebUtility]::HtmlEncode($DisplayName) -replace '\|', '&#124;'
            $DisplayName = $DisplayName -replace "`r?`n", ' '
            $Result += "`n| $($Item.ObjectId) | $DisplayName | $($Item.ObjectType) |"
        }

        Add-MtTestResultDetail -Result $Result -Severity 'Low'
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
