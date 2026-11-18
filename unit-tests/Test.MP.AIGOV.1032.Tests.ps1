# Dev-only Pester unit tests for Test-MPAIGOV1032. Not part of the installable pack.

BeforeAll {
    . "$PSScriptRoot/Support/Set-AIGovGraphRoute.ps1"
    . "$PSScriptRoot/../pack/helpers/Get-AIGovCostManagementSkipMessage.ps1"
    . "$PSScriptRoot/../pack/helpers/ConvertTo-AIGovMarkdownCell.ps1"
    . "$PSScriptRoot/../pack/helpers/ConvertTo-AIGovUtcDate.ps1"
    . "$PSScriptRoot/../pack/helpers/Test-AIGovNotFoundError.ps1"
    . "$PSScriptRoot/../pack/helpers/Get-AIGovCopilotLicenseState.ps1"
    . "$PSScriptRoot/../pack/tests/Test.MP.AIGOV.1032.ps1"

    $script:CopilotPlan = '3f30311c-6b1e-48a4-ab79-725b469da960'
    $script:CopilotSku = 'sku-copilot'
    $script:Skus = @(
        [pscustomobject]@{ skuId = $script:CopilotSku; servicePlans = @([pscustomobject]@{ servicePlanId = $script:CopilotPlan }) },
        [pscustomobject]@{ skuId = 'sku-e5'; servicePlans = @([pscustomobject]@{ servicePlanId = 'other-plan' }) }
    )

    function New-Member([string]$Id, [bool]$Enabled = $true, [string]$Type = 'Member', [string]$License = 'Working') {
        $Assigned = @(); $States = @()
        switch ($License) {
            'Working'    { $Assigned = @([pscustomobject]@{ skuId = $script:CopilotSku; disabledPlans = @() }); $States = @([pscustomobject]@{ skuId = $script:CopilotSku; state = 'Active' }) }
            'Turned off' { $Assigned = @([pscustomobject]@{ skuId = $script:CopilotSku; disabledPlans = @($script:CopilotPlan) }); $States = @([pscustomobject]@{ skuId = $script:CopilotSku; state = 'Active' }) }
            'Error'      { $Assigned = @([pscustomobject]@{ skuId = $script:CopilotSku; disabledPlans = @() }); $States = @([pscustomobject]@{ skuId = $script:CopilotSku; state = 'Error' }) }
        }
        [pscustomobject]@{ id = $Id; userPrincipalName = "$Id@contoso.com"; accountEnabled = $Enabled; userType = $Type; assignedLicenses = $Assigned; licenseAssignmentStates = $States }
    }

    function Get-Routes([object[]]$Members, [string[]]$Services = @('cowork'), [object]$SignIns = $null) {
        if ($null -eq $SignIns) {
            $Recent = [datetime]::UtcNow.AddDays(-5).ToString('o')
            $SignIns = @($Members | ForEach-Object { [pscustomobject]@{ id = $_.id; signInActivity = [pscustomobject]@{ lastSuccessfulSignInDateTime = $Recent } } })
        }
        @(
            , @('^copilot/costManagement/spendingPolicies$', @(New-AIGovPolicy -Id 'p1' -Name 'Cowork Limited'))
            , @('serviceSettings$', @($Services | ForEach-Object { [pscustomobject]@{ serviceId = $_; state = 'enabled' } }))
            , @('assignedGroups$', @([pscustomobject]@{ id = 'g1' }))
            , @('^subscribedSkus$', $script:Skus)
            , @('^groups/g1/transitiveMembers/microsoft\.graph\.user$', $Members)
            , @('^users$', $SignIns)
        )
    }
}

Describe 'Test-MPAIGOV1032' {
    BeforeEach { Mock Add-MtTestResultDetail { } }

    It 'passes when every member is enabled, active and licensed' {
        Set-AIGovGraphRoute (Get-Routes @((New-Member 'alice'), (New-Member 'bob')))
        Test-MPAIGOV1032 | Should -BeTrue
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Result -match 'No problems were found among 2 evaluated' }
    }

    It 'flags disabled, guest and license problems' {
        Set-AIGovGraphRoute (Get-Routes @(
                (New-Member 'off' -Enabled $false),
                (New-Member 'guest' -Type 'Guest'),
                (New-Member 'nolic' -License 'None'),
                (New-Member 'planoff' -License 'Turned off'),
                (New-Member 'err' -License 'Error'),
                (New-Member 'fine')))
        Test-MPAIGOV1032 | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Severity -eq 'Medium' -and $Result -match 'Found 5 of 6' -and
            $Result -match 'off@contoso.com.*Account is disabled' -and $Result -match 'guest@contoso.com.*Guest account' -and
            $Result -match 'nolic@contoso.com.*No Copilot license' -and $Result -match 'planoff@contoso.com.*turned off' -and
            $Result -match 'err@contoso.com.*has an error' -and $Result -notmatch 'fine@contoso.com'
        }
    }

    It 'does not check licenses when the policy has no licensed service' {
        Set-AIGovGraphRoute (Get-Routes @((New-Member 'nolic' -License 'None')) -Services @('workIQ'))
        Test-MPAIGOV1032 | Should -BeTrue
    }

    It 'flags inactive and never-signed-in members' {
        $Members = @((New-Member 'old'), (New-Member 'never'), (New-Member 'recent'))
        $SignIns = @(
            [pscustomobject]@{ id = 'old'; signInActivity = [pscustomobject]@{ lastSuccessfulSignInDateTime = [datetime]::UtcNow.AddDays(-200).ToString('o') } },
            [pscustomobject]@{ id = 'never'; signInActivity = [pscustomobject]@{ lastSuccessfulSignInDateTime = $null } },
            [pscustomobject]@{ id = 'recent'; signInActivity = [pscustomobject]@{ lastSuccessfulSignInDateTime = [datetime]::UtcNow.AddDays(-1) } }
        ) | Select-Object *, @{ Name = 'createdDateTime'; Expression = { [datetime]::UtcNow.AddDays(-365) } }
        Set-AIGovGraphRoute (Get-Routes $Members -SignIns $SignIns)
        Test-MPAIGOV1032 | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Result -match 'old@contoso.com.*No successful sign-in for 90 days' -and $Result -match 'never@contoso.com.*No sign-in recorded' -and
            $Result -notmatch 'recent@contoso.com'
        }
    }

    It 'skips only the sign-in check when signInActivity is forbidden' {
        $Routes = Get-Routes @((New-Member 'alice'))
        $Routes[-1] = @('^users$', 'throw:403 Forbidden: Authentication_RequestFromNonPremiumTenantOrB2CTenant')
        Set-AIGovGraphRoute $Routes
        Test-MPAIGOV1032 | Should -BeTrue
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Result -match 'sign-in check was skipped' }
    }

    It 'skips as partial coverage when clean members stop at MaxMembers' {
        Set-AIGovGraphRoute (Get-Routes @((New-Member 'a'), (New-Member 'b'), (New-Member 'c')))
        Test-MPAIGOV1032 -MaxMembers 2 | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $SkippedBecause -eq 'Custom' -and
            $SkippedCustomReason -match '^Partial coverage: checked 2 of 3 unique member\(s\) \(66%\)' -and
            $SkippedCustomReason -match 'AIGOV\.MaxSpendingPolicyMembers \(2\)'
        }
    }

    It 'leads a failure with the coverage when findings stop at MaxMembers' {
        Set-AIGovGraphRoute (Get-Routes @((New-Member 'off' -Enabled $false), (New-Member 'b'), (New-Member 'c'), (New-Member 'd')))
        Test-MPAIGOV1032 -MaxMembers 2 | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Severity -eq 'Medium' -and
            $Result -match '^Partial coverage: checked 2 of 4 unique member\(s\) \(50%\)' -and
            $Result -match 'Found 1 of 2 checked'
        }
    }

    It 'checks every member when MaxMembers is 0' {
        Set-AIGovGraphRoute (Get-Routes @((New-Member 'a'), (New-Member 'b'), (New-Member 'c')))
        Test-MPAIGOV1032 -MaxMembers 0 | Should -BeTrue
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Result -match 'among 3 evaluated' -and $Result -notmatch 'Partial coverage' }
    }

    It 'skips with Error when no group members can be read' {
        $Routes = Get-Routes @()
        $Routes[4] = @('^groups/g1/transitiveMembers/microsoft\.graph\.user$', 'throw:Service unavailable')
        Set-AIGovGraphRoute $Routes
        Test-MPAIGOV1032 | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'Error' }
    }

    It 'skips with NotAuthorized on a 403' {
        Mock Invoke-MtGraphRequest { throw [System.Exception]::new('403 Forbidden') }
        Test-MPAIGOV1032 | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'NotAuthorized' }
    }

    # Regression: confirmed live against the test tenant that $select=id alone on this beta
    # navigation property 404s, even though the exact same request with two or more fields succeeds.
    It 'asks for more than just id when reading assignedGroups' {
        Set-AIGovGraphRoute (Get-Routes @((New-Member 'alice')))
        Test-MPAIGOV1032 | Should -BeTrue
        Should -Invoke Invoke-MtGraphRequest -ParameterFilter {
            ([string]$RelativeUri[0]) -match 'assignedGroups$' -and @($Select).Count -gt 1 -and $Select -contains 'id'
        }
    }

    It 'reads sign-in activity in filtered groups instead of one request per member' {
        $Members = 1..16 | ForEach-Object { New-Member "member$_" }
        Set-AIGovGraphRoute (Get-Routes $Members)
        Test-MPAIGOV1032 | Should -BeTrue
        Should -Invoke Invoke-MtGraphRequest -Times 2 -ParameterFilter {
            $RelativeUri -eq 'users' -and $Select -contains 'signInActivity' -and $Select -contains 'createdDateTime' -and
            $Filter -match "^id in \(" -and -not $UniqueId
        }
        foreach ($Member in $Members) {
            $ExpectedId = "'" + $Member.id + "'"
            Should -Invoke Invoke-MtGraphRequest -Times 1 -Exactly -ParameterFilter {
                $RelativeUri -eq 'users' -and $Filter.Contains($ExpectedId)
            }
        }

    }

    It 'uses account age for null activity and reports new and unknown-age accounts separately' {
        $Members = @((New-Member 'old'), (New-Member 'new'), (New-Member 'unknown'))
        $SignIns = @(
            @{ id = 'old'; createdDateTime = [datetime]::UtcNow.AddDays(-100); signInActivity = $null }
            @{ id = 'new'; createdDateTime = [datetime]::UtcNow.AddDays(-5); signInActivity = $null }
            @{ id = 'unknown'; createdDateTime = $null; signInActivity = $null }
        )
        Set-AIGovGraphRoute (Get-Routes $Members -SignIns $SignIns)
        Test-MPAIGOV1032 | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Result -match 'Found 1 of 3' -and
            $Result -match 'old@contoso.com.*No sign-in recorded' -and
            $Result -notmatch 'new@contoso.com|unknown@contoso.com' -and
            $Result -match '1 older account\(s\) with no sign-in recorded' -and
            $Result -match '1 new accounts, too early to judge' -and
            $Result -match '1 account\(s\) with unknown history or age'
        }
    }

    It 'uses the later attempt when successful history is absent without overriding successful history' {
        $Recent = [datetime]::UtcNow.AddDays(-5)
        $Old = [datetime]::UtcNow.AddDays(-100).ToString('o')
        $Members = @('interactive', 'noninteractive', 'stale', 'successful') | ForEach-Object { New-Member $_ }
        $SignIns = @(
            @{ id = 'interactive'; signInActivity = @{ lastSuccessfulSignInDateTime = $null; lastSignInDateTime = $Recent; lastNonInteractiveSignInDateTime = $Old } }
            @{ id = 'noninteractive'; signInActivity = @{ lastSuccessfulSignInDateTime = $null; lastSignInDateTime = $Old; lastNonInteractiveSignInDateTime = $Recent } }
            @{ id = 'stale'; signInActivity = @{ lastSuccessfulSignInDateTime = $null; lastSignInDateTime = $Old; lastNonInteractiveSignInDateTime = $Old } }
            @{ id = 'successful'; signInActivity = @{ lastSuccessfulSignInDateTime = $Recent; lastSignInDateTime = $Old; lastNonInteractiveSignInDateTime = $Old } }
        )
        Set-AIGovGraphRoute (Get-Routes $Members -SignIns $SignIns)
        Test-MPAIGOV1032 | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Result -match 'Found 1 of 4' -and $Result -match 'stale@contoso.com.*No sign-in attempt for 90 days' -and
            $Result -notmatch 'interactive@contoso.com|successful@contoso.com' -and
            $Result -match '3 using last-attempt fallback'
        }
    }
}
