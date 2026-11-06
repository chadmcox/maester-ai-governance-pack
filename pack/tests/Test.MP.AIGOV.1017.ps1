function Test-MPAIGOV1017 {
    <#
    .SYNOPSIS
    Finds a tenant where no enabled Conditional Access policy targets agent identities.
    .DESCRIPTION
    Reads GET /identity/conditionalAccess/policies (graph-rest-beta -- the agent-identity targeting
    properties below do not exist on the v1.0 conditionalAccessClientApplications or
    conditionalAccessConditionSet resources, confirmed by comparing the beta and v1.0 schema
    reference pages). A policy "targets agent identities" when its
    conditions.clientApplications.includeAgentIdServicePrincipals is non-empty, its
    conditions.clientApplications.agentIdServicePrincipalFilter is set, or its
    conditions.agentIdRiskLevels is non-empty -- the exact property names from "Target agent
    identities in Microsoft Entra Conditional Access policies" and the conditionalAccessConditionSet
    / conditionalAccessClientApplications beta schema references.

    Two independent gap conditions, reported in one result table: (a) no *enabled* policy targets
    agent identities at all; (b) agent-targeting policies exist, but every one of them has state
    'disabled' or 'enabledForReportingButNotEnforced' (report-only), so none is actually enforced.

    This intentionally does not duplicate MT.1181 (Maester's own "Conditional Access policy is
    present that blocks high agent risk sign-ins"), confirmed by reading its source
    (Test-MtCaAgentRiskBlockPolicy.ps1): MT.1181 checks the narrow case of
    conditions.agentIdRiskLevels containing 'high' AND grantControls.builtInControls containing
    'block' on an enabled policy. This test is broader and upstream of that one -- it flags a
    tenant with no agent-identity-targeting Conditional Access coverage at all, regardless of
    control type, so a tenant that already has MT.1181 passing will also pass condition (a) here
    (since a block-on-high-risk policy also targets agent identities via agentIdRiskLevels), but a
    tenant that targets agent identities only with a non-block control, or only in report-only mode,
    is still flagged here even though it is out of MT.1181's narrower scope.
    .EXAMPLE
    Test-MPAIGOV1017
    .LINK
    https://learn.microsoft.com/entra/identity/conditional-access/howto-target-agent-identities
    .LINK
    https://learn.microsoft.com/graph/api/resources/conditionalaccessconditionset?view=graph-rest-beta
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1017',
        Title        = 'Conditional Access should cover agent identities',
        Product      = 'entra',
        Feature      = 'conditional-access',
        Area         = 'ai',
        ResourceType = 'Tenant',
        Severity     = 'High',
        Control      = 'nist-800-53-r5:AC-2(12)',
        Permission   = 'Graph:Application:Policy.Read.All',
        Service      = 'Graph',
        Lifecycle    = 'Preview'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        Write-Verbose 'Reading Conditional Access policies for agent identity targeting.'
        $Policies = @(
            Invoke-MtGraphRequest -ApiVersion 'beta' -RelativeUri 'identity/conditionalAccess/policies' `
                -Select @('id', 'displayName', 'state', 'conditions')
        )
    } catch {
        $ErrorRecord = $_
    }
    if ($ErrorRecord) {
        if ($ErrorRecord.Exception.Message -match '(?i)403|forbidden|authorization') {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized -Result (
                "Couldn't read Conditional Access policies (403). Confirm the Policy.Read.All " +
                'permission before re-running this check.'
            )
        } else {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $ErrorRecord
        }
        return $null
    }

    Write-Verbose "Found $($Policies.Count) Conditional Access policy(ies) in the tenant."

    $AgentTargeting = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($Policy in $Policies) {
        $ClientApps = $Policy.conditions.clientApplications
        $IncludesAgentIds = @($ClientApps.includeAgentIdServicePrincipals).Count -gt 0
        $HasAgentIdFilter = -not [string]::IsNullOrWhiteSpace([string]$ClientApps.agentIdServicePrincipalFilter.rule)
        $HasAgentRiskCondition = @($Policy.conditions.agentIdRiskLevels).Count -gt 0

        if (-not ($IncludesAgentIds -or $HasAgentIdFilter -or $HasAgentRiskCondition)) { continue }

        $AgentTargeting.Add([pscustomobject]@{
            PolicyId    = [string]$Policy.id
            DisplayName = [string]$Policy.displayName
            State       = [string]$Policy.state
            IsEnabled   = ([string]$Policy.state -eq 'enabled')
        })
    }

    $EnabledAgentTargeting = @($AgentTargeting | Where-Object { $_.IsEnabled })

    if ($EnabledAgentTargeting.Count -gt 0) {
        $Result = "Well done. $($EnabledAgentTargeting.Count) enabled Conditional Access policy(ies) " +
            "target agent identities (checked $($Policies.Count) polic(ies) total)."
        Add-MtTestResultDetail -Result $Result
        return $true
    }

    if ($AgentTargeting.Count -eq 0) {
        $Result = 'No Conditional Access policy targets agent identities ' +
            "(checked $($Policies.Count) polic(ies) total). Gap: no enabled policy targets agent " +
            'identities at all.'
        Add-MtTestResultDetail -Result $Result -Severity 'High'
        return $false
    }

    $Result = "Found $($AgentTargeting.Count) Conditional Access policy(ies) that target agent " +
        'identities, but none is enabled. Gap: agent-targeting policies exist, but every one is ' +
        'report-only or off.'
    $Result += "`n`n| Policy ID | Display name | State |"
    $Result += "`n| --- | --- | --- |"
    foreach ($Item in $AgentTargeting) {
        $Name = [string]$Item.DisplayName
        if ([string]::IsNullOrWhiteSpace($Name)) { $Name = '(unnamed)' }
        $Name = [System.Net.WebUtility]::HtmlEncode($Name) -replace '\|', '&#124;'
        $Name = $Name -replace "`r?`n", ' '
        $Result += "`n| $($Item.PolicyId) | $Name | $($Item.State) |"
    }

    Add-MtTestResultDetail -Result $Result -Severity 'High'
    return $false
}
