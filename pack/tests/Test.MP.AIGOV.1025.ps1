function Test-MPAIGOV1025 {
    <#
    .SYNOPSIS
    Finds Copilot spending policies that aren't scoped to a group or aren't fully configured.
    .DESCRIPTION
    Reads every spendingPolicy (beta Cost Management API) and applies the policy rules from
    chadmcox/Copilot "Billing Health Check":
      - High:   the policy covers all users (allUsersSpendingPolicy) instead of a security group.
      - High:   the policy's status isn't 'enabled'.
      - High:   a group-scoped policy has no group linked.
      - High:   a group linked to the policy no longer exists.
      - Medium: the billing method isn't set (notSpecified or empty).
      - Medium: the per-user limit is a cap below MinPerUserCredits (default 2,000). An unlimited
                per-user limit isn't reported here: MP.AIGOV.1013 covers policies with no ceiling.
    Policies with no overall ceiling (MP.AIGOV.1013), group owners and descriptions (MP.AIGOV.1014) and
    overlapping policies (MP.AIGOV.1015) are covered by those tests, not this one.
    .PARAMETER MinPerUserCredits
    The smallest per-user cap that isn't reported. Defaults to 2,000 credits.
    .EXAMPLE
    Test-MPAIGOV1025
    .EXAMPLE
    Test-MPAIGOV1025 -MinPerUserCredits 1000
    .LINK
    https://learn.microsoft.com/microsoft-365/copilot/extensibility/api/admin-settings/cost-management/spendingpolicy-list
    .LINK
    https://learn.microsoft.com/copilot/implement/usage-based-billing-manage-copilot-credits#add-identity-based-spending-policy
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1025',
        Title        = 'Spending policy should be scoped to a group and fully configured',
        Product      = 'entra',
        Feature      = 'cost-management',
        Area         = 'ai',
        ResourceType = 'Tenant',
        Severity     = 'High',
        Permission   = 'Graph:Application:CopilotCostManagement-Policy.Read.All|Graph:Application:CopilotCostManagement-Assignment.Read.All|Graph:Application:Group.Read.All',
        Service      = 'Graph',
        Lifecycle    = 'Preview'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The smallest per-user cap that isn't reported. Defaults to 2,000 credits.
        [Parameter(Mandatory = $false)]
        [int] $MinPerUserCredits = 2000
    )

    try {
        Write-Verbose 'Reading Copilot spending policies.'
        $Policies = @(
            Invoke-MtGraphRequest -ApiVersion 'beta' -RelativeUri 'copilot/costManagement/spendingPolicies' `
                -Select @('id', 'displayName', 'status', 'billingMethods', 'perUserLimit')
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

    if ($Policies.Count -eq 0) {
        Add-MtTestResultDetail -Result 'Well done. No Copilot spending policies were found in the tenant.'
        return $true
    }

    $Findings = [System.Collections.Generic.List[pscustomobject]]::new()
    $Unread = [System.Collections.Generic.List[string]]::new()

    foreach ($Policy in $Policies) {
        $Name = [string]$Policy.displayName
        $Type = [string]$Policy.'@odata.type'
        $Status = [string]$Policy.status

        if ($Type -match '(?i)allUsersSpendingPolicy$') {
            $Findings.Add([pscustomobject]@{ Policy = $Name; Severity = 'High'; Check = 'Covers all users'; Fix = 'Scope it to a security group.' })
        }

        if ($Status -ne 'enabled') {
            $Shown = if ([string]::IsNullOrWhiteSpace($Status)) { '(empty)' } else { $Status }
            $Findings.Add([pscustomobject]@{ Policy = $Name; Severity = 'High'; Check = "Status is $Shown"; Fix = 'Link the right group, or recreate the policy.' })
        }

        $Billing = @($Policy.billingMethods | ForEach-Object { [string]$_ } | Where-Object { $_ })
        if ($Billing.Count -eq 0 -or ($Billing | Where-Object { $_ -eq 'notSpecified' })) {
            $Findings.Add([pscustomobject]@{ Policy = $Name; Severity = 'Medium'; Check = 'Billing method not set'; Fix = 'Pick prepaid credits or pay-as-you-go.' })
        }

        $PerUser = Get-AIGovSpendingLimit -Limit $Policy.perUserLimit
        if ($PerUser.Known -and -not $PerUser.Unlimited -and $PerUser.Value -lt $MinPerUserCredits) {
            $Findings.Add([pscustomobject]@{
                Policy = $Name; Severity = 'Medium'; Check = "Per-user limit $($PerUser.Text) is below $MinPerUserCredits"
                Fix = "Raise it to at least $MinPerUserCredits credits, or lower MinPerUserCredits if this cap is intended."
            })
        }

        if ($Type -notmatch '(?i)selectedGroupsSpendingPolicy$') { continue }

        try {
            $Groups = @(
                Invoke-MtGraphRequest -ApiVersion 'beta' `
                    -RelativeUri "copilot/costManagement/spendingPolicies/$($Policy.id)/microsoft.graph.selectedGroupsSpendingPolicy/assignedGroups" `
                    -Select @('id', 'displayName')
            ) | Where-Object { $_ -and -not [string]::IsNullOrWhiteSpace([string]$_.id) }
        } catch {
            Write-Verbose "Couldn't read assignedGroups for spending policy $($Policy.id): $($_.Exception.Message)"
            $Unread.Add($Name)
            continue
        }

        if (@($Groups).Count -eq 0) {
            $Findings.Add([pscustomobject]@{ Policy = $Name; Severity = 'High'; Check = 'No group linked'; Fix = "Link the policy's security group." })
            continue
        }

        foreach ($Group in $Groups) {
            try {
                $null = Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri "groups/$($Group.id)" -Select @('id')
            } catch {
                if (Test-AIGovNotFoundError -ErrorRecord $_) {
                    $Findings.Add([pscustomobject]@{
                        Policy = $Name; Severity = 'High'; Check = "Linked group $($Group.id) no longer exists"
                        Fix = 'Link the right group.'
                    })
                } else {
                    Write-Verbose "Couldn't read group $($Group.id): $($_.Exception.Message)"
                    $Unread.Add("$Name (group $($Group.id))")
                }
            }
        }
    }

    $UnreadText = ''
    if ($Unread.Count -gt 0) {
        $UnreadText = " $($Unread.Count) item(s) couldn't be read and aren't reflected in this result: $(($Unread | ForEach-Object { ConvertTo-AIGovMarkdownCell -Text $_ }) -join ', ')."
    }

    if ($Findings.Count -eq 0) {
        Add-MtTestResultDetail -Result "Well done. All $($Policies.Count) spending policy(ies) are enabled, scoped to existing groups and fully configured.$UnreadText"
        return $true
    }

    $Rank = @{ High = 0; Medium = 1; Low = 2 }
    $Ordered = @($Findings | Sort-Object @{ Expression = { $Rank[$_.Severity] } }, Policy)
    $Result = "Found $($Findings.Count) spending policy problem(s).$UnreadText"
    $Result += "`n`n| Policy | Severity | Check | Fix |"
    $Result += "`n| --- | --- | --- | --- |"
    foreach ($Item in $Ordered) {
        $Result += "`n| $(ConvertTo-AIGovMarkdownCell -Text $Item.Policy) | $($Item.Severity) | $(ConvertTo-AIGovMarkdownCell -Text $Item.Check) | $(ConvertTo-AIGovMarkdownCell -Text $Item.Fix) |"
    }

    Add-MtTestResultDetail -Result $Result -Severity $Ordered[0].Severity
    return $false
}
