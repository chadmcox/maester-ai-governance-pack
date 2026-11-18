function Test-MPAIGOV1032 {
    <#
    .SYNOPSIS
    Finds people in Copilot spending-policy groups who shouldn't be spending credits.
    .DESCRIPTION
    For every user in a group linked to an enabled selectedGroupsSpendingPolicy (transitive membership),
    applies the member rules from chadmcox/Copilot "Billing Health Check". All are Medium:
      - The account is disabled.
      - The account is a guest (userType Guest).
      - No successful sign-in for InactiveDays (default 90), falling back to the latest interactive or
        non-interactive attempt when successful history is absent. Accounts without history are reported
        only once they are older than that window. Needs signInActivity (AuditLog.Read.All and Microsoft
        Entra ID P1); if that can't be read, this check is skipped and the result says so.
      - No working Microsoft 365 Copilot license, when the policy turns on a service that needs one
        (LicensedServices, default cowork and code). Working means a license whose SKU includes a Copilot
        service plan, with that plan not disabled and the assignment not in an error state.
    All-users policies are out of scope here (MP.AIGOV.1025 reports them).
    .PARAMETER InactiveDays
    Days without recorded sign-in activity before a member is reported. Successful activity is preferred;
    otherwise the latest attempt is used. Accounts with no history must also be older than this window.
    0 turns the sign-in check off.
    .PARAMETER LicensedServices
    Spending-policy service IDs that only work for people with a Copilot license.
    .PARAMETER CopilotServicePlanIds
    Service plan IDs that make a SKU a Copilot license. The default is M365_COPILOT_BUSINESS_CHAT,
    which is in every Microsoft 365 Copilot SKU.
    .PARAMETER MaxMembers
    The most unique members evaluated in one run (setting AIGOV.MaxSpendingPolicyMembers, default 5000).
    Members beyond this are counted, not checked, and the result leads with the coverage. 0 means no cap.
    .EXAMPLE
    Test-MPAIGOV1032
    .EXAMPLE
    Test-MPAIGOV1032 -InactiveDays 45
    .LINK
    https://learn.microsoft.com/copilot/implement/usage-based-billing-manage-copilot-credits
    .LINK
    https://learn.microsoft.com/graph/api/resources/signinactivity
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1032',
        Title        = 'Spending policy groups should contain only enabled, active, licensed members',
        Product      = 'entra',
        Feature      = 'cost-management',
        Area         = 'ai',
        ResourceType = 'User',
        Severity     = 'Medium',
        Permission   = 'Graph:Application:CopilotCostManagement-Policy.Read.All|Graph:Application:CopilotCostManagement-Assignment.Read.All|Graph:Application:GroupMember.Read.All|Graph:Application:User.Read.All|Graph:Application:AuditLog.Read.All|Graph:Application:Organization.Read.All',
        Service      = 'Graph',
        Lifecycle    = 'Preview'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $false)]
        [int] $InactiveDays = 90,

        [Parameter(Mandatory = $false)]
        [string[]] $LicensedServices = @('cowork', 'code'),

        [Parameter(Mandatory = $false)]
        [string[]] $CopilotServicePlanIds = @('3f30311c-6b1e-48a4-ab79-725b469da960'),

        [MaesterParameter(Setting = 'AIGOV.MaxSpendingPolicyMembers')]
        [ValidateRange(0, 1000000)]
        [int] $MaxMembers = 5000
    )

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
    $Policies = @($Policies)
    if ($Policies.Count -eq 0) {
        Add-MtTestResultDetail -Result 'Well done. No enabled, group-scoped Copilot spending policies were found in the tenant.'
        return $true
    }

    $Notes = [System.Collections.Generic.List[string]]::new()

    # Copilot SKUs in this tenant.
    $CopilotSkuIds = @()
    $LicenseCheck = $true
    try {
        $CopilotSkuIds = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri 'subscribedSkus' -Select @('skuId', 'servicePlans') |
                Where-Object { @($_.servicePlans | Where-Object { [string]$_.servicePlanId -in $CopilotServicePlanIds }).Count -gt 0 } |
                ForEach-Object { [string]$_.skuId }
        )
    } catch {
        Write-Verbose "Couldn't read subscribedSkus: $($_.Exception.Message)"
        $LicenseCheck = $false
        $Notes.Add("The license check was skipped: subscribedSkus couldn't be read (needs Organization.Read.All or Directory.Read.All).")
    }

    # User ID -> member record (policies, and whether any of them needs a license).
    $Members = @{}
    $Unread = [System.Collections.Generic.List[string]]::new()
    # Unique members past MaxMembers. A HashSet so a user in several groups is counted once.
    $SkippedIds = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($Policy in $Policies) {
        $PolicyName = [string]$Policy.displayName
        $Base = "copilot/costManagement/spendingPolicies/$($Policy.id)"
        try {
            $Services = @(
                Invoke-MtGraphRequest -ApiVersion 'beta' -RelativeUri "$Base/serviceSettings" |
                    Where-Object { [string]$_.state -eq 'enabled' } | ForEach-Object { [string]$_.serviceId }
            )
            # Confirmed live: $select=id alone on this beta navigation property 404s; asking for a
            # second property (here displayName) works. Keep at least two fields in -Select.
            $Groups = @(
                Invoke-MtGraphRequest -ApiVersion 'beta' -RelativeUri "$Base/microsoft.graph.selectedGroupsSpendingPolicy/assignedGroups" -Select @('id', 'displayName')
            )
        } catch {
            Write-Verbose "Couldn't read services or groups for spending policy $($Policy.id): $($_.Exception.Message)"
            $Unread.Add($PolicyName)
            continue
        }
        $NeedsLicense = @($Services | Where-Object { $_ -in $LicensedServices }).Count -gt 0

        foreach ($Group in $Groups) {
            if ([string]::IsNullOrWhiteSpace([string]$Group.id)) { continue }
            try {
                $Users = @(
                    Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri "groups/$($Group.id)/transitiveMembers/microsoft.graph.user" `
                        -Select @('id', 'userPrincipalName', 'accountEnabled', 'userType', 'assignedLicenses', 'licenseAssignmentStates')
                )
            } catch {
                if (-not (Test-AIGovNotFoundError -ErrorRecord $_)) {
                    Write-Verbose "Couldn't read members of group $($Group.id): $($_.Exception.Message)"
                    $Unread.Add("$PolicyName (group $($Group.id))")
                }
                continue
            }
            foreach ($User in $Users) {
                $Id = [string]$User.id
                if ([string]::IsNullOrWhiteSpace($Id)) { continue }
                if (-not $Members.ContainsKey($Id)) {
                    if ($MaxMembers -gt 0 -and $Members.Count -ge $MaxMembers) { [void]$SkippedIds.Add($Id); continue }
                    $Members[$Id] = [pscustomobject]@{
                        User         = $User
                        Policies     = [System.Collections.Generic.List[string]]::new()
                        NeedsLicense = $false
                    }
                }
                if ($PolicyName -notin $Members[$Id].Policies) { $Members[$Id].Policies.Add($PolicyName) }
                if ($NeedsLicense) { $Members[$Id].NeedsLicense = $true }
            }
        }
    }

    if ($Members.Count -eq 0) {
        if ($Unread.Count -gt 0) {
            Add-MtTestResultDetail -SkippedBecause Error -Result "Couldn't read the members of any spending-policy group ($($Unread.Count) item(s) failed)."
            return $null
        }
        Add-MtTestResultDetail -Result 'Well done. The groups behind enabled spending policies have no user members.'
        return $true
    }

    # Read small filtered collections rather than one throttled sign-in request per user.
    $SignIns = @{}
    $SignInCheck = $InactiveDays -gt 0
    if ($SignInCheck) {
        try {
            $Activity = @(
                $MemberIds = @($Members.Keys)
                for ($Start = 0; $Start -lt $MemberIds.Count; $Start = $Start + 15) {
                    $Last = [math]::Min($Start + 14, $MemberIds.Count - 1)
                    $Filter = "id in ('" + ($MemberIds[$Start..$Last] -join "','") + "')"
                    Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri 'users' -Filter $Filter -Select @('id', 'createdDateTime', 'signInActivity')
                }
            )
            foreach ($Item in $Activity) {
                if ($Item -and $Item.id) { $SignIns[[string]$Item.id] = $Item }
            }
        } catch {
            Write-Verbose "Couldn't read signInActivity: $($_.Exception.Message)"
            $SignInCheck = $false
            $Notes.Add("The sign-in check was skipped: signInActivity couldn't be read (needs AuditLog.Read.All and Microsoft Entra ID P1).")
        }
    } else {
        $Notes.Add('The sign-in check is turned off (InactiveDays is 0).')
    }
    $Cutoff = [datetime]::UtcNow.AddDays(-$InactiveDays)
    $OldWithoutHistory = 0
    $NewWithoutHistory = 0
    $UnknownHistory = 0
    $FallbackCount = 0
    $StaleSignIns = 0

    $Findings = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($Id in $Members.Keys) {
        $Entry = $Members[$Id]
        $User = $Entry.User
        $Issues = [System.Collections.Generic.List[string]]::new()

        if (-not [bool]$User.accountEnabled) { $Issues.Add('Account is disabled') }
        if ([string]$User.userType -eq 'Guest') { $Issues.Add('Guest account') }

        if ($SignInCheck -and $SignIns.ContainsKey($Id)) {
            $Record = $SignIns[$Id]
            $Activity = $Record.signInActivity
            $UsingFallback = $null -ne $Activity -and [string]::IsNullOrWhiteSpace([string]$Activity.lastSuccessfulSignInDateTime)
            $RawDates = @($Activity.lastSuccessfulSignInDateTime)
            if ($UsingFallback) {
                $FallbackCount++
                $RawDates = @($Activity.lastSignInDateTime, $Activity.lastNonInteractiveSignInDateTime)
            }
            $RawDates = @($RawDates | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
            $LastDate = $RawDates | ForEach-Object { ConvertTo-AIGovUtcDate -Value $_ } |
                Sort-Object -Descending | Select-Object -First 1
            if ($null -ne $LastDate) {
                if ($LastDate -lt $Cutoff) {
                    $StaleSignIns++
                    $Message = if ($UsingFallback) { 'No sign-in attempt' } else { 'No successful sign-in' }
                    $Issues.Add("$Message for $InactiveDays days (last $($LastDate.ToString('yyyy-MM-dd')))")
                }
            } elseif ($RawDates.Count -gt 0) {
                $UnknownHistory++
            } else {
                $Created = ConvertTo-AIGovUtcDate -Value $Record.createdDateTime
                if ($null -eq $Created) {
                    $UnknownHistory++
                } elseif ($Created -lt $Cutoff) {
                    $OldWithoutHistory++
                    $Issues.Add('No sign-in recorded')
                } else {
                    $NewWithoutHistory++
                }
            }
        } elseif ($SignInCheck) {
            $UnknownHistory++
        }

        if ($LicenseCheck -and $Entry.NeedsLicense) {
            $State = Get-AIGovCopilotLicenseState -User $User -CopilotSkuIds $CopilotSkuIds -CopilotServicePlanIds $CopilotServicePlanIds
            switch ($State) {
                'None' { $Issues.Add('No Copilot license, but a policy turns on a service that needs one') }
                'Turned off' { $Issues.Add('Copilot is turned off in their license') }
                'Error' { $Issues.Add('Their Copilot license assignment has an error') }
            }
        }

        if ($Issues.Count -gt 0) {
            $Upn = if ($User.userPrincipalName) { [string]$User.userPrincipalName } else { $Id }
            $Findings.Add([pscustomobject]@{ User = $Upn; Policies = ($Entry.Policies -join ', '); Issues = ($Issues -join '; ') })
        }
    }

    $Coverage = ''
    if ($SkippedIds.Count -gt 0) {
        $Total = $Members.Count + $SkippedIds.Count
        $Percent = [math]::Floor(100 * $Members.Count / $Total)
        $Coverage = "Partial coverage: checked $($Members.Count) of $Total unique member(s) ($Percent%). " +
            "$($SkippedIds.Count) member(s) beyond AIGOV.MaxSpendingPolicyMembers ($MaxMembers) weren't checked; raise the setting, or set it to 0 for no cap, to check them."
    }
    if ($Unread.Count -gt 0) {
        $Notes.Add("$($Unread.Count) item(s) couldn't be read and aren't reflected in this result: $(($Unread | ForEach-Object { ConvertTo-AIGovMarkdownCell -Text $_ }) -join ', ').")
    }
    $NoteText = if ($Notes.Count -gt 0) { "`n`n" + (($Notes | ForEach-Object { "- $_" }) -join "`n") } else { '' }
    $ActivitySummary = if ($SignInCheck) {
        " Sign-in history: $OldWithoutHistory older account(s) with no sign-in recorded; $NewWithoutHistory new accounts, too early to judge; $UnknownHistory account(s) with unknown history or age; $FallbackCount using last-attempt fallback; $StaleSignIns stale activity record(s)."
    } else { '' }

    if ($Findings.Count -eq 0 -and $Coverage) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason (
            "$Coverage No problems were found among the members that were checked.$ActivitySummary$NoteText"
        )
        return $null
    }

    if ($Findings.Count -eq 0) {
        Add-MtTestResultDetail -Result "Well done. No problems were found among $($Members.Count) evaluated spending-policy group member(s).$ActivitySummary$NoteText"
        return $true
    }

    $MaxRows = 100
    $Ordered = @($Findings | Sort-Object User)
    $Result = $(if ($Coverage) { "$Coverage`n`n" } else { '' }) + "Found $($Findings.Count) of $($Members.Count) checked spending-policy group member(s) who shouldn't be spending credits as they are.$ActivitySummary$NoteText"
    $Result += "`n`n| User | Policies | Issues |"
    $Result += "`n| --- | --- | --- |"
    foreach ($Item in ($Ordered | Select-Object -First $MaxRows)) {
        $Result += "`n| $(ConvertTo-AIGovMarkdownCell -Text $Item.User) | $(ConvertTo-AIGovMarkdownCell -Text $Item.Policies) | $(ConvertTo-AIGovMarkdownCell -Text $Item.Issues) |"
    }
    if ($Ordered.Count -gt $MaxRows) { $Result += "`n`n...and $($Ordered.Count - $MaxRows) more." }

    Add-MtTestResultDetail -Result $Result -Severity 'Medium'
    return $false
}
