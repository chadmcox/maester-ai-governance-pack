function Test-MPAIGOV1015 {
    <#
    .SYNOPSIS
    Finds groups where a spending policy's per-user cap has no effect because another policy also applies.
    .DESCRIPTION
    Microsoft documents that when more than one spending policy applies to a user, the most permissive
    policy is enforced: the higher limit applies, and limits from overlapping policies aren't combined.
    So when a group is covered by two enabled policies, the policy with the lower per-user limit does
    nothing for the people in that group.

    This test reads every enabled spendingPolicy (beta Cost Management API). For each enabled
    selectedGroupsSpendingPolicy it reads assignedGroups. An enabled allUsersSpendingPolicy applies to
    every group as well. For each group covered by two or more enabled policies, it works out the
    effective per-user limit (Unlimited beats any cap, otherwise the highest cap) and reports:
      - High:   a policy's cap is overridden by a policy with an unlimited per-user limit.
      - Medium: a policy's cap is overridden by a policy with a higher per-user cap.
      - Low:    the group is in two or more group-scoped policies with the same per-user limit (redundant
                overlap), or the limits can't be compared (missing limit or different units).
    A group whose own group-scoped policy is the most permissive one, layered over an all-users base
    policy, is the normal tiering pattern and is not reported.
    .EXAMPLE
    Test-MPAIGOV1015
    .LINK
    https://learn.microsoft.com/copilot/implement/usage-based-billing-manage-copilot-studio-costs#understand-policy-hierarchy
    .LINK
    https://learn.microsoft.com/microsoft-365/copilot/extensibility/api/admin-settings/cost-management/spendingpolicy-list-assignedgroups
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1015',
        Title        = 'Spending policy cap should not be overridden by a more permissive overlapping policy',
        Product      = 'entra',
        Feature      = 'cost-management',
        Area         = 'ai',
        ResourceType = 'Tenant',
        Severity     = 'Medium',
        Permission   = 'Graph:Application:CopilotCostManagement-Assignment.Read.All',
        Service      = 'Graph',
        Lifecycle    = 'Preview'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        Write-Verbose 'Reading Copilot spending policies.'
        $AllPolicies = @(
            Invoke-MtGraphRequest -ApiVersion 'beta' -RelativeUri 'copilot/costManagement/spendingPolicies' `
                -Select @('id', 'displayName', 'status', 'periodLimit', 'perUserLimit')
        )
    } catch {
        $ErrorRecord = $_
    }
    if ($ErrorRecord) {
        if ($ErrorRecord.Exception.Message -match '(?i)403|forbidden|authorization') {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized -Result (Get-AIGovCostManagementSkipMessage)
        } else {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $ErrorRecord
        }
        return $null
    }

    $Enabled = @($AllPolicies | Where-Object { [string]$_.status -eq 'enabled' })
    $AllUsersPolicies = @($Enabled | Where-Object { [string]$_.'@odata.type' -match '(?i)allUsersSpendingPolicy$' })
    $GroupPolicies = @($Enabled | Where-Object { [string]$_.'@odata.type' -match '(?i)selectedGroupsSpendingPolicy$' })

    # Audience key -> list of applicable policies. 'All users' is its own audience so that two
    # enabled all-users policies are compared with each other too.
    $Audiences = @{}
    $FailedPolicyCount = 0
    foreach ($Policy in $GroupPolicies) {
        try {
            $AssignedGroups = @(
                Invoke-MtGraphRequest -ApiVersion 'beta' `
                    -RelativeUri "copilot/costManagement/spendingPolicies/$($Policy.id)/microsoft.graph.selectedGroupsSpendingPolicy/assignedGroups" `
                    -Select @('id', 'displayName')
            )
        } catch {
            Write-Verbose "Couldn't read assignedGroups for spending policy $($Policy.id): $($_.Exception.Message)"
            $FailedPolicyCount++
            continue
        }
        foreach ($Group in $AssignedGroups) {
            if ([string]::IsNullOrWhiteSpace([string]$Group.id)) { continue }
            Add-AIGovSpendingAudiencePolicy -Audiences $Audiences -Key ([string]$Group.id) -DisplayName ([string]$Group.displayName) -Policy $Policy -IsGroupScoped
        }
    }

    if ($GroupPolicies.Count -gt 0 -and $FailedPolicyCount -eq $GroupPolicies.Count) {
        Add-MtTestResultDetail -SkippedBecause Error -Result (
            "Couldn't read the assigned groups for any of the $($GroupPolicies.Count) group-scoped spending " +
            'policies, so overlap couldn''t be evaluated. See verbose output for details.'
        )
        return $null
    }

    # An all-users policy applies to every group that has its own policy, and to the 'All users' audience.
    $GroupKeys = @($Audiences.Keys)
    foreach ($Policy in $AllUsersPolicies) {
        foreach ($Key in $GroupKeys) {
            Add-AIGovSpendingAudiencePolicy -Audiences $Audiences -Key $Key -DisplayName ([string]$Audiences[$Key].DisplayName) -Policy $Policy
        }
        Add-AIGovSpendingAudiencePolicy -Audiences $Audiences -Key 'All users' -DisplayName 'All users' -Policy $Policy
    }

    $Findings = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($Audience in $Audiences.Values) {
        $Applicable = @($Audience.Policies)
        if ($Applicable.Count -lt 2) { continue }

        $Unknown = @($Applicable | Where-Object { -not $_.PerUser.Known })
        $Units = @($Applicable | Where-Object { $_.PerUser.Known -and -not $_.PerUser.Unlimited } |
            ForEach-Object { $_.PerUser.Unit } | Sort-Object -Unique)
        $AllText = ($Applicable | ForEach-Object { "$($_.Name) ($($_.PerUser.Text))" }) -join '; '

        if ($Unknown.Count -gt 0 -or $Units.Count -gt 1) {
            $Findings.Add([pscustomobject]@{
                Audience = $Audience.DisplayName; AudienceId = $Audience.Key; Severity = 'Low'
                Effective = 'Cannot determine'; Overridden = '-'; Policies = $AllText
                Reason = 'A per-user limit is missing, unreadable, or in a different unit, so the effective limit cannot be worked out.'
            })
            continue
        }

        $UnlimitedPolicies = @($Applicable | Where-Object { $_.PerUser.Unlimited })
        if ($UnlimitedPolicies.Count -gt 0) {
            $EffectiveText = 'Unlimited'
            $Winners = $UnlimitedPolicies
            $Losers = @($Applicable | Where-Object { -not $_.PerUser.Unlimited })
        } else {
            $Max = ($Applicable | Measure-Object -Property { $_.PerUser.Value } -Maximum).Maximum
            $Winners = @($Applicable | Where-Object { $_.PerUser.Value -eq $Max })
            $Losers = @($Applicable | Where-Object { $_.PerUser.Value -lt $Max })
            $EffectiveText = $Winners[0].PerUser.Text
        }

        if ($Losers.Count -gt 0) {
            # A group-scoped policy winning over an all-users base policy is normal tiering.
            $WinnerIsGroupTier = @($Winners | Where-Object { $_.IsGroupScoped }).Count -gt 0
            $LosersAreBaseOnly = @($Losers | Where-Object { $_.IsGroupScoped }).Count -eq 0
            if ($WinnerIsGroupTier -and $LosersAreBaseOnly) { continue }

            $Findings.Add([pscustomobject]@{
                Audience = $Audience.DisplayName; AudienceId = $Audience.Key
                Severity = if ($UnlimitedPolicies.Count -gt 0) { 'High' } else { 'Medium' }
                Effective = "$EffectiveText (from $(($Winners.Name | Sort-Object -Unique) -join ', '))"
                Overridden = ($Losers | ForEach-Object { "$($_.Name) ($($_.PerUser.Text))" }) -join '; '
                Policies = $AllText
                Reason = 'The most permissive policy applies, so the lower per-user cap has no effect for this audience.'
            })
            continue
        }

        # Same limit everywhere. Only report when two or more group-scoped policies overlap.
        if (@($Applicable | Where-Object { $_.IsGroupScoped }).Count -ge 2) {
            $Findings.Add([pscustomobject]@{
                Audience = $Audience.DisplayName; AudienceId = $Audience.Key; Severity = 'Low'
                Effective = $EffectiveText; Overridden = '-'; Policies = $AllText
                Reason = 'Redundant overlap: the group is in more than one policy with the same per-user limit.'
            })
        }
    }

    $FailedText = ''
    if ($FailedPolicyCount -gt 0) {
        $FailedText = " $FailedPolicyCount group-scoped policy(ies) could not be read and are not reflected in this result."
    }

    if ($Findings.Count -eq 0) {
        Add-MtTestResultDetail -Result (
            "Well done. No enabled spending policy has a per-user cap overridden by a more permissive overlapping " +
            "policy ($($Enabled.Count) enabled policy(ies), $($Audiences.Count) audience(s) checked).$FailedText"
        )
        return $true
    }

    $Ordered = @($Findings | Sort-Object @{ Expression = { @{ High = 0; Medium = 1; Low = 2 }[$_.Severity] } }, Audience)
    $Highest = $Ordered[0].Severity

    $Result = "Found $($Findings.Count) audience(s) where overlapping spending policies change or obscure the effective per-user limit. " +
        "When more than one policy applies, the most permissive one is enforced.$FailedText"
    $Result += "`n`n| Audience | Severity | Effective per-user limit | Overridden policies | All applicable policies | Why |"
    $Result += "`n| --- | --- | --- | --- | --- | --- |"
    foreach ($Item in $Ordered) {
        $Name = if ([string]::IsNullOrWhiteSpace($Item.Audience)) { $Item.AudienceId } else { "$($Item.Audience) ($($Item.AudienceId))" }
        $Result += "`n| $(ConvertTo-AIGovMarkdownCell -Text $Name) | $($Item.Severity) | $(ConvertTo-AIGovMarkdownCell -Text $Item.Effective) | $(ConvertTo-AIGovMarkdownCell -Text $Item.Overridden) | " +
            "$(ConvertTo-AIGovMarkdownCell -Text $Item.Policies) | $(ConvertTo-AIGovMarkdownCell -Text $Item.Reason) |"
    }

    Add-MtTestResultDetail -Result $Result -Severity $Highest
    return $false
}
