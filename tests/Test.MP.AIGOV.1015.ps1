function Test-MPAIGOV1015 {
    <#
    .SYNOPSIS
    Finds a group assigned to more than one enabled Copilot spending policy.
    .DESCRIPTION
    Reads every enabled, group-scoped `selectedGroupsSpendingPolicy` and its `assignedGroups`
    (confirmed live 2026-11-06, same sub-resource as MP.AIGOV.1014). Flags any group ID that backs
    more than one enabled policy at once: with two enabled policies targeting the same audience,
    whichever applies first is implementation-defined, and the two caps -- if they differ -- are not
    a single reviewable ceiling. A tenant can legitimately scope every group to exactly one policy; the
    live test tenant currently shows zero such overlaps across its 8 group-scoped enabled policies,
    which this test treats as a well-formed negative, not evidence the condition can't occur.
    .EXAMPLE
    Test-MPAIGOV1015
    .LINK
    https://learn.microsoft.com/microsoft-365/copilot/extensibility/api/admin-settings/cost-management/spendingpolicy-list-assignedgroups
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1015',
        Title        = 'Group should not be assigned to more than one enabled spending policy',
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
        Write-Verbose 'Reading enabled, group-scoped Copilot spending policies for overlapping group assignment.'
        $Policies = @(
            Invoke-MtGraphRequest -ApiVersion 'beta' -RelativeUri 'copilot/costManagement/spendingPolicies' `
                -Select @('id', 'displayName', 'status')
        ) | Where-Object { [string]$_.status -eq 'enabled' -and [string]$_.'@odata.type' -match '(?i)selectedGroupsSpendingPolicy$' }

        $GroupToPolicies = @{}
        foreach ($Policy in $Policies) {
            $AssignedGroups = @(
                Invoke-MtGraphRequest -ApiVersion 'beta' `
                    -RelativeUri "copilot/costManagement/spendingPolicies/$($Policy.id)/microsoft.graph.selectedGroupsSpendingPolicy/assignedGroups" `
                    -Select @('id', 'displayName')
            )
            foreach ($Group in $AssignedGroups) {
                $GroupId = [string]$Group.id
                if (-not $GroupToPolicies.ContainsKey($GroupId)) {
                    $GroupToPolicies[$GroupId] = [pscustomobject]@{
                        GroupId     = $GroupId
                        DisplayName = [string]$Group.displayName
                        Policies    = [System.Collections.Generic.List[string]]::new()
                    }
                }
                $GroupToPolicies[$GroupId].Policies.Add([string]$Policy.displayName)
            }
        }
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

    if ($GroupToPolicies.Count -eq 0) {
        Add-MtTestResultDetail -Result (
            'Well done. No group-scoped Copilot spending policies were found in the tenant.'
        )
        return $true
    }

    $Overlapping = @($GroupToPolicies.Values | Where-Object { $_.Policies.Count -gt 1 })

    if ($Overlapping.Count -eq 0) {
        Add-MtTestResultDetail -Result (
            'Well done. No group is assigned to more than one enabled Copilot spending policy.'
        )
        return $true
    }

    $Result = "Found $($Overlapping.Count) group(s) assigned to more than one enabled Copilot spending policy."
    $Result += "`n`n| Group ID | Display name | Policies |"
    $Result += "`n| --- | --- | --- |"
    foreach ($Item in $Overlapping) {
        $Name = [string]$Item.DisplayName
        if ([string]::IsNullOrWhiteSpace($Name)) { $Name = '(unnamed)' }
        $Name = [System.Net.WebUtility]::HtmlEncode($Name) -replace '\|', '&#124;'
        $Name = $Name -replace "`r?`n", ' '
        $Policies = [System.Net.WebUtility]::HtmlEncode(($Item.Policies -join ', ')) -replace '\|', '&#124;'
        $Result += "`n| $($Item.GroupId) | $Name | $Policies |"
    }

    Add-MtTestResultDetail -Result $Result -Severity 'Medium'
    return $false
}
