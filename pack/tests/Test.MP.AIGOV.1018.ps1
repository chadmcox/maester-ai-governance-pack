function Test-MPAIGOV1018 {
    <#
    .SYNOPSIS
    Finds agent identities currently at risk that have not been remediated or dismissed.
    .DESCRIPTION
    Reads GET /identityProtection/riskyAgents (graph-rest-beta -- confirmed via the
    Microsoft.Graph.Beta.Identity.SignIns PowerShell module reference, the documented endpoint for
    this resource; no v1.0 equivalent exists today). The riskyAgent resource carries riskState
    (none, confirmedSafe, dismissed, atRisk, confirmedCompromised, unknownFutureValue),
    agentDisplayName, blueprintId, identityType, isEnabled, isDeleted, riskLevel, riskDetail, and
    riskLastModifiedDateTime. "At risk and not yet remediated or dismissed" maps specifically to
    riskState eq 'atRisk': confirmedSafe and dismissed are both post-investigation resolved states,
    and confirmedCompromised means a worse, already-confirmed state rather than an unremediated
    pending one -- this test still surfaces confirmedCompromised agents separately in the result so
    neither state is silently dropped, but only atRisk drives the Fail/Severity outcome described
    by this finding's title. Uses the least-privileged Graph permission confirmed in the permissions
    reference, IdentityRiskyAgent.Read.All -- a distinct permission from
    IdentityRiskyServicePrincipal.Read.All, which covers a different, non-agent resource. The Learn
    page for this feature currently states Identity Protection for agents will require a Microsoft
    Agent 365 license "starting soon" (not required at the time this test was written).
    .EXAMPLE
    Test-MPAIGOV1018
    .LINK
    https://learn.microsoft.com/powershell/module/microsoft.graph.beta.identity.signins/get-mgbetariskyagent?view=graph-powershell-beta
    .LINK
    https://learn.microsoft.com/graph/permissions-reference
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1018',
        Title        = 'Agent identity currently at risk should be remediated or dismissed',
        Product      = 'entra',
        Feature      = 'agent-identities',
        Area         = 'ai',
        ResourceType = 'Agent',
        Severity     = 'High',
        Control      = 'nist-800-53-r5:AC-6',
        Permission   = 'Graph:Application:IdentityRiskyAgent.Read.All',
        Service      = 'Graph',
        Lifecycle    = 'Preview'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        Write-Verbose 'Reading risky agent identities.'
        $RiskyAgents = @(
            Invoke-MtGraphRequest -ApiVersion 'beta' -RelativeUri 'identityProtection/riskyAgents' `
                -Select @('id', 'agentDisplayName', 'riskState', 'riskLevel', 'riskDetail', 'isEnabled', 'isDeleted')
        )
    } catch {
        $ErrorRecord = $_
    }
    if ($ErrorRecord) {
        if ($ErrorRecord.Exception.Message -match '(?i)403|forbidden|authorization') {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized -Result (
                "Couldn't read risky agent identities (403). Confirm the IdentityRiskyAgent.Read.All " +
                'permission before re-running this check.'
            )
        } else {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $ErrorRecord
        }
        return $null
    }

    Write-Verbose "Found $($RiskyAgents.Count) risky agent identity record(s) total."

    $AtRisk = @($RiskyAgents | Where-Object { [string]$_.riskState -eq 'atRisk' })
    $ConfirmedCompromised = @($RiskyAgents | Where-Object { [string]$_.riskState -eq 'confirmedCompromised' })

    if ($AtRisk.Count -eq 0 -and $ConfirmedCompromised.Count -eq 0) {
        $Result = 'Well done. No agent identity is currently at risk ' +
            "($($RiskyAgents.Count) risky agent record(s) checked)."
        Add-MtTestResultDetail -Result $Result
        return $true
    }

    $Result = if ($AtRisk.Count -gt 0) {
        "Found $($AtRisk.Count) agent identity(ies) at risk and not yet remediated or dismissed."
    } else {
        'Found no agent identity still at risk, but found agent identity(ies) already confirmed compromised.'
    }
    if ($ConfirmedCompromised.Count -gt 0) {
        $Result += " $($ConfirmedCompromised.Count) additional agent identity(ies) are already " +
            'confirmedCompromised and are listed separately below.'
    }
    $Result += "`n`n| Agent object ID | Display name | Risk state | Risk level | Enabled |"
    $Result += "`n| --- | --- | --- | --- | --- |"
    foreach ($Item in (@($AtRisk) + @($ConfirmedCompromised))) {
        $Name = [string]$Item.agentDisplayName
        if ([string]::IsNullOrWhiteSpace($Name)) { $Name = '(unnamed)' }
        $Name = [System.Net.WebUtility]::HtmlEncode($Name) -replace '\|', '&#124;'
        $Name = $Name -replace "`r?`n", ' '
        $EnabledText = if ($Item.isEnabled -eq $true) { 'Yes' } elseif ($Item.isEnabled -eq $false) { 'No' } else { '(unknown)' }
        $Result += "`n| $([string]$Item.id) | $Name | $([string]$Item.riskState) | $([string]$Item.riskLevel) | $EnabledText |"
    }

    Add-MtTestResultDetail -Result $Result -Severity 'High'
    return $false
}
