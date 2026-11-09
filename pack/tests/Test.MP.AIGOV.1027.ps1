function Test-MPAIGOV1027 {
    <#
    .SYNOPSIS
    Finds groups behind enabled Copilot spending policies that aren't plain, populated security groups.
    .DESCRIPTION
    For every group linked to an enabled selectedGroupsSpendingPolicy, applies the group rules from
    chadmcox/Copilot "Billing Health Check":
      - Medium: Microsoft 365 group (groupTypes contains Unified) or not security-enabled. Microsoft
                documents security groups as the way to scope users to a spending policy.
      - Medium: has nested groups. Microsoft doesn't document whether spending policies count nested members.
      - Low:    has no members.
      - Info:   dynamic group (groupTypes contains DynamicMembership). Fine for broad audiences; spend tiers
                are better managed with access packages so membership is requested and reviewed.
    Owners and descriptions are MP.AIGOV.1014; a linked group that no longer exists is MP.AIGOV.1025.
    .EXAMPLE
    Test-MPAIGOV1027
    .LINK
    https://learn.microsoft.com/copilot/implement/usage-based-billing-manage-copilot-credits#add-identity-based-spending-policy
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1027',
        Title        = 'Group behind a spending policy should be a populated security group without nesting',
        Product      = 'entra',
        Feature      = 'cost-management',
        Area         = 'ai',
        ResourceType = 'Group',
        Severity     = 'Medium',
        Permission   = 'Graph:Application:CopilotCostManagement-Assignment.Read.All|Graph:Application:Group.Read.All',
        Service      = 'Graph',
        Lifecycle    = 'Preview'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        Write-Verbose 'Reading enabled, group-scoped Copilot spending policies.'
        $Policies = @(
            Invoke-MtGraphRequest -ApiVersion 'beta' -RelativeUri 'copilot/costManagement/spendingPolicies' `
                -Select @('id', 'displayName', 'status')
        ) | Where-Object { [string]$_.status -eq 'enabled' -and [string]$_.'@odata.type' -match '(?i)selectedGroupsSpendingPolicy$' }
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

    $Unread = [System.Collections.Generic.List[string]]::new()
    $GroupPolicies = @{}
    foreach ($Policy in @($Policies)) {
        try {
            # Confirmed live: $select=id alone on this beta navigation property 404s; asking for a
            # second property (here displayName) works. Keep at least two fields in -Select.
            $Assigned = @(
                Invoke-MtGraphRequest -ApiVersion 'beta' `
                    -RelativeUri "copilot/costManagement/spendingPolicies/$($Policy.id)/microsoft.graph.selectedGroupsSpendingPolicy/assignedGroups" `
                    -Select @('id', 'displayName')
            )
        } catch {
            Write-Verbose "Couldn't read assignedGroups for spending policy $($Policy.id): $($_.Exception.Message)"
            $Unread.Add([string]$Policy.displayName)
            continue
        }
        foreach ($Group in $Assigned) {
            $Id = [string]$Group.id
            if ([string]::IsNullOrWhiteSpace($Id)) { continue }
            if (-not $GroupPolicies.ContainsKey($Id)) { $GroupPolicies[$Id] = [System.Collections.Generic.List[string]]::new() }
            $GroupPolicies[$Id].Add([string]$Policy.displayName)
        }
    }

    if ($GroupPolicies.Count -eq 0) {
        if ($Unread.Count -gt 0) {
            Add-MtTestResultDetail -SkippedBecause Error -Result "Couldn't read the assigned groups for any enabled group-scoped spending policy."
            return $null
        }
        Add-MtTestResultDetail -Result 'Well done. No enabled, group-scoped Copilot spending policies were found in the tenant.'
        return $true
    }

    $Findings = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($Id in $GroupPolicies.Keys) {
        $PolicyText = ($GroupPolicies[$Id] | Sort-Object -Unique) -join ', '
        try {
            $Group = Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri "groups/$Id" -Select @('id', 'displayName', 'groupTypes', 'securityEnabled')
            $Nested = @(Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri "groups/$Id/members/microsoft.graph.group" -Select @('id', 'displayName'))
            $AnyMember = @(Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri "groups/$Id/members" -Select @('id') `
                    -QueryParameters @{ '$top' = 1 } -DisablePaging)
        } catch {
            if (-not (Test-AIGovNotFoundError -ErrorRecord $_)) {
                Write-Verbose "Couldn't read group $Id`: $($_.Exception.Message)"
                $Unread.Add("group $Id")
            }
            # A group that no longer exists is reported by MP.AIGOV.1025.
            continue
        }

        $Name = if ([string]::IsNullOrWhiteSpace([string]$Group.displayName)) { $Id } else { "$($Group.displayName) ($Id)" }
        $Types = @($Group.groupTypes | ForEach-Object { [string]$_ })

        if ($Types -contains 'Unified' -or -not [bool]$Group.securityEnabled) {
            $Kind = if ($Types -contains 'Unified') { 'Microsoft 365 group' } else { 'Not security-enabled' }
            $Findings.Add([pscustomobject]@{ Group = $Name; Policies = $PolicyText; Severity = 'Medium'; Check = $Kind; Fix = 'Use a security group.' })
        }
        $Nested = @($Nested | Where-Object { $_ -and -not [string]::IsNullOrWhiteSpace([string]$_.id) })
        if ($Nested.Count -gt 0) {
            $NestedNames = ($Nested | ForEach-Object { if ($_.displayName) { [string]$_.displayName } else { [string]$_.id } }) -join ', '
            $Findings.Add([pscustomobject]@{
                Group = $Name; Policies = $PolicyText; Severity = 'Medium'; Check = "Has nested groups: $NestedNames"
                Fix = "Add people directly; Microsoft doesn't document whether spending policies count nested members."
            })
        }
        if (@($AnyMember | Where-Object { $_ }).Count -eq 0) {
            $Findings.Add([pscustomobject]@{ Group = $Name; Policies = $PolicyText; Severity = 'Low'; Check = 'Group is empty'; Fix = 'Retire the policy, or fill the group.' })
        }
        if ($Types -contains 'DynamicMembership') {
            $Findings.Add([pscustomobject]@{
                Group = $Name; Policies = $PolicyText; Severity = 'Info'; Check = 'Dynamic group'
                Fix = 'Fine for broad audiences; for spend tiers, use access packages so membership is requested and reviewed.'
            })
        }
    }

    $UnreadText = ''
    if ($Unread.Count -gt 0) {
        $UnreadText = " $($Unread.Count) item(s) couldn't be read and aren't reflected in this result: $(($Unread | ForEach-Object { ConvertTo-AIGovMarkdownCell -Text $_ }) -join ', ')."
    }

    if ($Findings.Count -eq 0) {
        Add-MtTestResultDetail -Result "Well done. All $($GroupPolicies.Count) group(s) behind enabled spending policies are populated security groups without nesting.$UnreadText"
        return $true
    }

    $Rank = @{ High = 0; Medium = 1; Low = 2; Info = 3 }
    $Ordered = @($Findings | Sort-Object @{ Expression = { $Rank[$_.Severity] } }, Group)
    $Result = "Found $($Findings.Count) problem(s) with groups behind enabled spending policies.$UnreadText"
    $Result += "`n`n| Group | Policies | Severity | Check | Fix |"
    $Result += "`n| --- | --- | --- | --- | --- |"
    foreach ($Item in $Ordered) {
        $Result += "`n| $(ConvertTo-AIGovMarkdownCell -Text $Item.Group) | $(ConvertTo-AIGovMarkdownCell -Text $Item.Policies) | $($Item.Severity) | " +
            "$(ConvertTo-AIGovMarkdownCell -Text $Item.Check) | $(ConvertTo-AIGovMarkdownCell -Text $Item.Fix) |"
    }

    # Info-only findings (dynamic groups) aren't a failure.
    if (-not ($Findings | Where-Object { $_.Severity -ne 'Info' })) {
        Add-MtTestResultDetail -Result $Result -Severity 'Info'
        return $true
    }
    Add-MtTestResultDetail -Result $Result -Severity $Ordered[0].Severity
    return $false
}
