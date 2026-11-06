function Test-MPAIGOV1014 {
    <#
    .SYNOPSIS
    Finds groups backing a Copilot spending policy with no owner or no description.
    .DESCRIPTION
    A `selectedGroupsSpendingPolicy` scopes itself to one or more groups through the
    `assignedGroups` navigation property (`GET .../{id}/microsoft.graph.selectedGroupsSpendingPolicy/
    assignedGroups`), confirmed live 2026-11-06 against the test tenant. This test reads every
    enabled, group-scoped policy's assigned groups and flags any group with fewer than 2 owners
    (including the common case of zero) or a blank `description`: a spending-policy audience with no
    one accountable for its membership, or no recorded reason for its existence, is itself a
    governance gap, independent of the policy's own settings. Live run found all 8 distinct groups
    backing policies in the test tenant had zero owners.
    .EXAMPLE
    Test-MPAIGOV1014
    .EXAMPLE
    Test-MPAIGOV1014 -MinOwnerCount 1
    .LINK
    https://learn.microsoft.com/microsoft-365/copilot/extensibility/api/admin-settings/cost-management/spendingpolicy-list-assignedgroups
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1014',
        Title        = 'Group backing a spending policy should have owners and a description',
        Product      = 'entra',
        Feature      = 'cost-management',
        Area         = 'ai',
        ResourceType = 'Group',
        Severity     = 'Low',
        Permission   = 'Graph:Application:CopilotCostManagement-Assignment.Read.All',
        Service      = 'Graph',
        Lifecycle    = 'Preview'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Minimum number of owners a backing group should have. Defaults to 2 (redundancy, not a single point of failure).
        [Parameter(Mandatory = $false)]
        [int] $MinOwnerCount = 2
    )

    try {
        Write-Verbose 'Reading enabled, group-scoped Copilot spending policies.'
        $Policies = @(
            Invoke-MtGraphRequest -ApiVersion 'beta' -RelativeUri 'copilot/costManagement/spendingPolicies' `
                -Select @('id', 'displayName', 'status')
        ) | Where-Object { [string]$_.status -eq 'enabled' -and [string]$_.'@odata.type' -match '(?i)selectedGroupsSpendingPolicy$' }

        $GroupToPolicies = @{}
        foreach ($Policy in $Policies) {
            $AssignedGroups = @(
                Invoke-MtGraphRequest -ApiVersion 'beta' `
                    -RelativeUri "copilot/costManagement/spendingPolicies/$($Policy.id)/microsoft.graph.selectedGroupsSpendingPolicy/assignedGroups" `
                    -Select @('id', 'displayName', 'description')
            )
            foreach ($Group in $AssignedGroups) {
                $GroupId = [string]$Group.id
                if (-not $GroupToPolicies.ContainsKey($GroupId)) {
                    $GroupToPolicies[$GroupId] = [pscustomobject]@{
                        GroupId     = $GroupId
                        DisplayName = [string]$Group.displayName
                        Description = [string]$Group.description
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

    $Flagged = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($Group in $GroupToPolicies.Values) {
        try {
            $Owners = @(Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri "groups/$($Group.GroupId)/owners" -Select @('id'))
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

        $HasNoDescription = [string]::IsNullOrWhiteSpace($Group.Description)
        $HasTooFewOwners = $Owners.Count -lt $MinOwnerCount
        if (-not $HasNoDescription -and -not $HasTooFewOwners) { continue }

        $Flagged.Add([pscustomobject]@{
            GroupId     = $Group.GroupId
            DisplayName = $Group.DisplayName
            OwnerCount  = $Owners.Count
            HasDescription = -not $HasNoDescription
            Policies    = ($Group.Policies -join ', ')
        })
    }

    if ($Flagged.Count -eq 0) {
        Add-MtTestResultDetail -Result (
            "Well done. Every group backing a spending policy has at least $MinOwnerCount owner(s) and a description."
        )
        return $true
    }

    $Result = "Found $($Flagged.Count) group(s) backing a spending policy with fewer than $MinOwnerCount owner(s) or no description."
    $Result += "`n`n| Group ID | Display name | Owner count | Has description | Policies |"
    $Result += "`n| --- | --- | --- | --- | --- |"
    foreach ($Item in $Flagged) {
        $Name = [string]$Item.DisplayName
        if ([string]::IsNullOrWhiteSpace($Name)) { $Name = '(unnamed)' }
        $Name = [System.Net.WebUtility]::HtmlEncode($Name) -replace '\|', '&#124;'
        $Name = $Name -replace "`r?`n", ' '
        $Policies = [System.Net.WebUtility]::HtmlEncode($Item.Policies) -replace '\|', '&#124;'
        $Result += "`n| $($Item.GroupId) | $Name | $($Item.OwnerCount) | $($Item.HasDescription) | $Policies |"
    }

    Add-MtTestResultDetail -Result $Result -Severity 'Low'
    return $false
}
