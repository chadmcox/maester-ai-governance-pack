function Test-MPAIGOV1023 {
    <#
    .SYNOPSIS
    Finds agent identities and blueprints with unclear names, and blueprints with poor descriptions.
    .DESCRIPTION
    Applies the naming rules from chadmcox/Copilot "Agent and Tools Health Check" to Entra Agent ID objects
    (MP.AIGOV.1006 does the same for catalog packages):
      - Unclear name (agent identities and blueprints registered in this tenant): empty, fewer than 4
        characters, a placeholder word (test, demo, sample, sandbox, temp, tmp, copy, draft, POC, untitled,
        dummy, delete me, do not use), "new/my agent" and similar, or a trailing number or copy marker.
        The " (Microsoft Copilot Studio)" suffix is ignored.
      - Poor description (blueprints): empty, under 20 characters, or the same as the name.
    The word list is that repo's, not Microsoft's; Microsoft recommends a naming convention but publishes
    no list. A reviewer who can't tell what an agent does or who owns it can't judge its access.
    .EXAMPLE
    Test-MPAIGOV1023
    .LINK
    https://learn.microsoft.com/entra/agent-id/agent-blueprint
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1023',
        Title        = 'Agent identity and blueprint should have a clear name and description',
        Product      = 'entra',
        Feature      = 'agent-identities',
        Area         = 'ai',
        ResourceType = 'ServicePrincipal',
        Severity     = 'Medium',
        Permission   = 'Graph:Application:Application.Read.All',
        Service      = 'Graph',
        Lifecycle    = 'Preview'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        Write-Verbose 'Reading agent identities and agent identity blueprints.'
        $Identities = @(Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri 'servicePrincipals/microsoft.graph.agentIdentity' -Select @('id', 'displayName'))
        $Blueprints = @(Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri 'applications/microsoft.graph.agentIdentityBlueprint' -Select @('id', 'displayName', 'description'))
    } catch {
        $ErrorRecord = $_
    }
    if ($ErrorRecord) {
        if ($ErrorRecord.Exception.Message -match '(?i)403|forbidden|authorization') {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
        } else {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $ErrorRecord
        }
        return $null
    }

    $Identities = @($Identities | Where-Object { $_ -and $_.id })
    $Blueprints = @($Blueprints | Where-Object { $_ -and $_.id })
    $Findings = [System.Collections.Generic.List[pscustomobject]]::new()

    foreach ($Identity in $Identities) {
        if (Test-AIGovUnclearName -Name $Identity.displayName) {
            $Findings.Add([pscustomobject]@{ Kind = 'Agent identity'; Id = [string]$Identity.id; Name = [string]$Identity.displayName; Issues = 'Unclear name' })
        }
    }
    foreach ($Blueprint in $Blueprints) {
        $Issues = [System.Collections.Generic.List[string]]::new()
        if (Test-AIGovUnclearName -Name $Blueprint.displayName) { $Issues.Add('Unclear name') }
        if (Test-AIGovPoorDescription -Description $Blueprint.description -Name $Blueprint.displayName) { $Issues.Add('Poor description') }
        if ($Issues.Count -gt 0) {
            $Findings.Add([pscustomobject]@{ Kind = 'Blueprint'; Id = [string]$Blueprint.id; Name = [string]$Blueprint.displayName; Issues = $Issues -join '; ' })
        }
    }

    if ($Findings.Count -eq 0) {
        Add-MtTestResultDetail -Result "Well done. All $($Identities.Count) agent identities and $($Blueprints.Count) blueprints have clear names, and every blueprint has a description."
        return $true
    }

    $Result = "Found $($Findings.Count) agent identities or blueprints that are hard to identify. Rename them so people can tell what they do and who owns them, and describe each blueprint's purpose, scope and owning team."
    $Result += "`n`n| Kind | Object ID | Name | Issues |"
    $Result += "`n| --- | --- | --- | --- |"
    foreach ($Item in ($Findings | Sort-Object Kind, Name)) {
        $Name = if ([string]::IsNullOrWhiteSpace($Item.Name)) { '(empty)' } else { $Item.Name }
        $Result += "`n| $($Item.Kind) | $(ConvertTo-AIGovMarkdownCell -Text $Item.Id) | $(ConvertTo-AIGovMarkdownCell -Text $Name) | $($Item.Issues) |"
    }

    Add-MtTestResultDetail -Result $Result -Severity 'Medium'
    return $false
}
