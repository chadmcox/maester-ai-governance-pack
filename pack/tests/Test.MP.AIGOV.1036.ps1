function Test-MPAIGOV1036 {
    <#
    .SYNOPSIS
    Finds enabled agent identities whose sponsors are all disabled or gone.
    .DESCRIPTION
    Reads GET /servicePrincipals/microsoft.graph.agentIdentity, then each enabled agent identity's
    sponsors (GET /servicePrincipals/{id}/microsoft.graph.agentIdentity/sponsors). A sponsor counts
    as active when it is a group, or a user whose accountEnabled isn't false. An enabled agent
    identity fails when it has no active sponsor: no sponsors left, or every sponsor's account is
    disabled.

    Microsoft Entra requires a sponsor when an agent identity is created, so this state usually
    follows a sponsor leaving without a Lifecycle Workflows sponsor transfer. CISA's draft SCuBA agent
    baseline (MS.SI.3.1) says every agent SHALL have a sponsor and an owner.

    MT.1205 checks sponsors on blueprints and blueprint principals only; MP.AIGOV.1004 flags exactly
    one sponsor with zero owners. This test covers agent identities whose sponsor accountability
    has already lapsed.
    .EXAMPLE
    Test-MPAIGOV1036
    .LINK
    https://learn.microsoft.com/entra/agent-id/agent-owners-sponsors-managers
    .LINK
    https://learn.microsoft.com/entra/id-governance/agent-sponsor-tasks
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1036',
        Title        = 'Enabled agent identities should have at least one active sponsor',
        Product      = 'entra',
        Feature      = 'agent-identities',
        Area         = 'ai',
        ResourceType = 'Agent',
        Severity     = 'Medium',
        Control      = 'nist-800-53-r5:AC-2',
        Permission   = 'Graph:Application:Application.Read.All',
        Service      = 'Graph',
        Lifecycle    = 'Preview',
        LongRunning
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        Write-Verbose 'Reading agent identities.'
        $Identities = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri 'servicePrincipals/microsoft.graph.agentIdentity' `
                -Select @('id', 'displayName', 'appId', 'accountEnabled')
        )
    } catch {
        if ($_.Exception.Message -match '(?i)403|forbidden|authorization') {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized -Result (
                "Couldn't read agent identities (403). Confirm the Application.Read.All permission before re-running this check."
            )
        } else {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        }
        return $null
    }

    $Enabled = @($Identities | Where-Object { $null -ne $_ -and $_.accountEnabled -ne $false })
    $FailedReads = [System.Collections.Generic.List[string]]::new()

    $Findings = @(
        foreach ($Identity in $Enabled) {
            try {
                $Sponsors = @(
                    Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri "servicePrincipals/$($Identity.id)/microsoft.graph.agentIdentity/sponsors" `
                        -Select @('id', 'displayName', 'accountEnabled') | Where-Object { $null -ne $_ }
                )
            } catch {
                Write-Verbose "Couldn't read sponsors for $($Identity.id): $($_.Exception.Message)"
                $FailedReads.Add([string]$Identity.id)
                continue
            }

            $Active = @($Sponsors | Where-Object {
                    $null -ne $_ -and ([string]$_.'@odata.type' -match 'group' -or $_.accountEnabled -ne $false)
                })
            if ($Active.Count -eq 0) {
                $Identity | Select-Object @{ n = 'Agent identity'; e = { [string]$_.displayName } },
                    @{ n = 'Object ID'; e = { [string]$_.id } },
                    @{ n = 'Sponsors'; e = { $Sponsors.Count } },
                    @{ n = 'Reason'; e = { if ($Sponsors.Count -eq 0) { 'no sponsor' } else { 'every sponsor is disabled' } } }
            }
        }
    )

    $ReadNote = if ($FailedReads.Count -gt 0) {
        "`n`n$($FailedReads.Count) agent identit(ies) couldn't be read and aren't reflected in this result."
    } else { '' }

    if ($Enabled.Count -gt 0 -and $FailedReads.Count -eq $Enabled.Count) {
        Add-MtTestResultDetail -SkippedBecause Error -Result "Couldn't read sponsors for any of the $($Enabled.Count) enabled agent identities."
        return $null
    }

    if ($Findings.Count -eq 0) {
        Add-MtTestResultDetail -Result "Well done. All $($Enabled.Count) enabled agent identit(ies) have an active sponsor.$ReadNote"
        return $true
    }

    $Result = @(
        "Found $($Findings.Count) enabled agent identit(ies) with no active sponsor. Assign a sponsor, or disable the agent identity if no one owns its purpose."
        $Findings | ConvertTo-AIGovMarkdownTable -Property 'Agent identity', 'Object ID', 'Sponsors', 'Reason'
    ) -join "`n`n"
    Add-MtTestResultDetail -Result ($Result + $ReadNote) -Severity 'Medium'
    return $false
}
