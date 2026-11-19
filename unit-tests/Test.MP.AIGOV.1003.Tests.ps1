BeforeAll {
    . "$PSScriptRoot/Support/Set-AIGovGraphRoute.ps1"
    . "$PSScriptRoot/../pack/helpers/Get-AIGovPackageCatalogSkipMessage.ps1"
    . "$PSScriptRoot/../pack/tests/Test.MP.AIGOV.1003.ps1"

    $script:Catalog = @(
        @{ id = 'p1'; displayName = 'Expense agent' },
        @{ id = 'p2'; displayName = 'HR agent' }
    )
}

Describe 'Test-MPAIGOV1003' {
    BeforeEach {
        Mock Add-MtTestResultDetail {}
    }

    It 'passes when every assignment goes through a group' {
        Set-AIGovGraphRoute @(
            , @('^copilot/admin/catalog/packages$', $Catalog)
            , @('^copilot/admin/catalog/packages/p\d$', @{ allowedUsersAndGroups = @(@{ resourceType = 'group'; resourceId = 'g1' }) })
        )
        Test-MPAIGOV1003 | Should -Be $true
    }

    It 'fails Low for a direct user assignment' {
        Set-AIGovGraphRoute @(
            , @('^copilot/admin/catalog/packages$', $Catalog)
            , @('^copilot/admin/catalog/packages/p1$', @{ acquireUsersAndGroups = @(@{ resourceType = 'user'; resourceId = 'u1' }) })
            , @('^copilot/admin/catalog/packages/p2$', @{ allowedUsersAndGroups = @() })
        )
        Test-MPAIGOV1003 | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Severity -eq 'Low' -and $Result -match 'p1 \| Expense agent \| 1' }
    }

    It 'skips as a partial check instead of passing when some package reads fail' {
        Set-AIGovGraphRoute @(
            , @('^copilot/admin/catalog/packages$', $Catalog)
            , @('^copilot/admin/catalog/packages/p1$', 'throw:429 Too Many Requests')
            , @('^copilot/admin/catalog/packages/p2$', @{ allowedUsersAndGroups = @() })
        )
        Test-MPAIGOV1003 | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $SkippedBecause -eq 'Custom' -and $SkippedCustomReason -match '^Partial check' -and $SkippedCustomReason -match '1 of 2 package'
        }
    }

    It 'notes unread packages beside a finding' {
        Set-AIGovGraphRoute @(
            , @('^copilot/admin/catalog/packages$', $Catalog)
            , @('^copilot/admin/catalog/packages/p1$', @{ acquireUsersAndGroups = @(@{ resourceType = 'user'; resourceId = 'u1' }) })
            , @('^copilot/admin/catalog/packages/p2$', 'throw:429 Too Many Requests')
        )
        Test-MPAIGOV1003 | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Result -match "1 of 2 package\(s\) couldn't be read" }
    }

    It 'skips with an error when no package detail can be read' {
        Set-AIGovGraphRoute @(
            , @('^copilot/admin/catalog/packages$', $Catalog)
            , @('^copilot/admin/catalog/packages/p\d$', 'throw:429 Too Many Requests')
        )
        Test-MPAIGOV1003 | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'Error' }
    }
}
