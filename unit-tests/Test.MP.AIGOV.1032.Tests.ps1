# Dev-only Pester unit tests for Test-MPAIGOV1032. Not part of the installable pack.

BeforeAll {
    . "$PSScriptRoot/Support/Set-AIGovGraphRoute.ps1"
    . "$PSScriptRoot/../pack/helpers/Get-AIGovCostManagementSkipMessage.ps1"
    . "$PSScriptRoot/../pack/helpers/ConvertTo-AIGovMarkdownCell.ps1"
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
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Result -match 'Well done. All 2 member' }
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
        )
        Set-AIGovGraphRoute (Get-Routes $Members -SignIns $SignIns)
        Test-MPAIGOV1032 | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Result -match 'old@contoso.com.*No successful sign-in for 90 days' -and $Result -match 'never@contoso.com.*No successful sign-in recorded' -and
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

    It 'stops at MaxMembers and says how many were not checked' {
        Set-AIGovGraphRoute (Get-Routes @((New-Member 'a'), (New-Member 'b'), (New-Member 'c')))
        Test-MPAIGOV1032 -MaxMembers 2 | Should -BeTrue
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Result -match "1 member\(s\) beyond MaxMembers \(2\) weren't checked" }
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
}
