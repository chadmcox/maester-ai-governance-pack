# Dev-only Pester unit tests for Test-MPAIGOV1025. Not part of the installable pack.

BeforeAll {
    . "$PSScriptRoot/Support/Set-AIGovGraphRoute.ps1"
    . "$PSScriptRoot/../pack/helpers/Get-AIGovCostManagementSkipMessage.ps1"
    . "$PSScriptRoot/../pack/helpers/Get-AIGovSpendingLimit.ps1"
    . "$PSScriptRoot/../pack/helpers/ConvertTo-AIGovMarkdownCell.ps1"
    . "$PSScriptRoot/../pack/helpers/Test-AIGovNotFoundError.ps1"
    . "$PSScriptRoot/../pack/tests/Test.MP.AIGOV.1025.ps1"
}

Describe 'Test-MPAIGOV1025' {
    BeforeEach { Mock Add-MtTestResultDetail { } }

    It 'passes for an enabled, group-scoped, fully configured policy' {
        Set-AIGovGraphRoute @(
            , @('^copilot/costManagement/spendingPolicies$', @(New-AIGovPolicy -Id 'p1' -Name 'Pilot' -PerUser 5000))
            , @('assignedGroups$', @([pscustomobject]@{ id = 'g1'; displayName = 'Pilot users' }))
            , @('^groups/g1$', [pscustomobject]@{ id = 'g1' })
        )
        Test-MPAIGOV1025 | Should -BeTrue
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Result -match 'Well done' }
    }

    It 'flags an all-users policy as High' {
        Set-AIGovGraphRoute @( , @('^copilot/costManagement/spendingPolicies$', @(New-AIGovPolicy -Id 'p1' -Name 'Everyone' -Kind 'all'))) 
        Test-MPAIGOV1025 | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Severity -eq 'High' -and $Result -match 'Covers all users' }
    }

    It 'flags a disabled policy, missing billing method and low per-user cap' {
        Set-AIGovGraphRoute @(
            , @('^copilot/costManagement/spendingPolicies$', @(New-AIGovPolicy -Id 'p1' -Name 'Odd' -Status 'disabled' -PerUser 500 -Billing @('notSpecified')))
            , @('assignedGroups$', @([pscustomobject]@{ id = 'g1' }))
            , @('^groups/g1$', [pscustomobject]@{ id = 'g1' })
        )
        Test-MPAIGOV1025 | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Severity -eq 'High' -and $Result -match 'Status is disabled' -and $Result -match 'Billing method not set' -and $Result -match 'below 2000'
        }
    }

    It 'does not flag an unlimited per-user limit (MP.AIGOV.1013 covers ceilings)' {
        Set-AIGovGraphRoute @(
            , @('^copilot/costManagement/spendingPolicies$', @(New-AIGovPolicy -Id 'p1' -Name 'Open' -PerUser 'unlimited'))
            , @('assignedGroups$', @([pscustomobject]@{ id = 'g1' }))
            , @('^groups/g1$', [pscustomobject]@{ id = 'g1' })
        )
        Test-MPAIGOV1025 | Should -BeTrue
    }

    It 'flags a group policy with no group, and one whose group was deleted' {
        Set-AIGovGraphRoute @(
            , @('^copilot/costManagement/spendingPolicies$', @(
                    (New-AIGovPolicy -Id 'p1' -Name 'Empty scope' -PerUser 5000),
                    (New-AIGovPolicy -Id 'p2' -Name 'Ghost group' -PerUser 5000)))
            , @('spendingPolicies/p1/.*assignedGroups$', @())
            , @('spendingPolicies/p2/.*assignedGroups$', @([pscustomobject]@{ id = 'gone' }))
            , @('^groups/gone$', 'throw:Response status code does not indicate success: 404 (Not Found).')
        )
        Test-MPAIGOV1025 | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Result -match 'Empty scope.*No group linked' -and $Result -match 'Linked group gone no longer exists'
        }
    }

    It 'reports an unreadable group instead of calling it deleted' {
        Set-AIGovGraphRoute @(
            , @('^copilot/costManagement/spendingPolicies$', @(New-AIGovPolicy -Id 'p1' -Name 'Pilot' -PerUser 5000))
            , @('assignedGroups$', @([pscustomobject]@{ id = 'g1' }))
            , @('^groups/g1$', 'throw:Service unavailable')
        )
        Test-MPAIGOV1025 | Should -BeTrue
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Result -match "couldn't be read" -and $Result -notmatch 'no longer exists' }
    }

    It 'honours MinPerUserCredits' {
        Set-AIGovGraphRoute @(
            , @('^copilot/costManagement/spendingPolicies$', @(New-AIGovPolicy -Id 'p1' -Name 'Pilot' -PerUser 1500))
            , @('assignedGroups$', @([pscustomobject]@{ id = 'g1' }))
            , @('^groups/g1$', [pscustomobject]@{ id = 'g1' })
        )
        Test-MPAIGOV1025 -MinPerUserCredits 1000 | Should -BeTrue
    }

    It 'skips with NotAuthorized on a 403' {
        Mock Invoke-MtGraphRequest { throw [System.Exception]::new('403 Forbidden') }
        Test-MPAIGOV1025 | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'NotAuthorized' }
    }
}
