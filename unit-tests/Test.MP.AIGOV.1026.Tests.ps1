# Dev-only Pester unit tests for Test-MPAIGOV1026. Not part of the installable pack.

BeforeAll {
    . "$PSScriptRoot/Support/Set-AIGovGraphRoute.ps1"
    . "$PSScriptRoot/../pack/helpers/Get-AIGovCostManagementSkipMessage.ps1"
    . "$PSScriptRoot/../pack/helpers/ConvertTo-AIGovMarkdownCell.ps1"
    . "$PSScriptRoot/../pack/helpers/Test-AIGovNotFoundError.ps1"
    . "$PSScriptRoot/../pack/tests/Test.MP.AIGOV.1026.ps1"

    $script:Policy = New-AIGovPolicy -Id 'p1' -Name 'Pilot'
    $script:Alice = [pscustomobject]@{ id = 'u1'; userPrincipalName = 'alice@contoso.com'; accountEnabled = $true }
    $script:Bob = [pscustomobject]@{ id = 'u2'; userPrincipalName = 'bob@contoso.com'; accountEnabled = $true }
}

Describe 'Test-MPAIGOV1026' {
    BeforeEach { Mock Add-MtTestResultDetail { } }

    It 'passes with an alert and two active recipients' {
        Set-AIGovGraphRoute @(
            , @('^copilot/costManagement/spendingPolicies$', @($script:Policy))
            , @('emailThresholdSettings/recipients$', @([pscustomobject]@{ id = 'u1' }, [pscustomobject]@{ id = 'u2' }))
            , @('emailThresholdSettings$', [pscustomobject]@{ isEnabled = $true })
            , @('^users/u1$', $script:Alice)
            , @('^users/u2$', $script:Bob)
        )
        Test-MPAIGOV1026 | Should -BeTrue
    }

    It 'flags a policy with no alert (404 or isEnabled false)' {
        Set-AIGovGraphRoute @(
            , @('^copilot/costManagement/spendingPolicies$', @($script:Policy, (New-AIGovPolicy -Id 'p2' -Name 'Second')))
            , @('p1/emailThresholdSettings$', 'throw:404 Not Found')
            , @('p2/emailThresholdSettings$', [pscustomobject]@{ isEnabled = $false })
        )
        Test-MPAIGOV1026 | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Severity -eq 'Medium' -and ([regex]::Matches($Result, 'No email alert')).Count -eq 2
        }
    }

    It 'flags one recipient (Low), a disabled recipient and a deleted recipient (Medium)' {
        $Disabled = [pscustomobject]@{ id = 'u3'; userPrincipalName = 'carol@contoso.com'; accountEnabled = $false }
        Set-AIGovGraphRoute @(
            , @('^copilot/costManagement/spendingPolicies$', @($script:Policy, (New-AIGovPolicy -Id 'p2' -Name 'Second')))
            , @('p1/emailThresholdSettings/recipients$', @([pscustomobject]@{ id = 'u1' }))
            , @('p2/emailThresholdSettings/recipients$', @([pscustomobject]@{ id = 'u3' }, [pscustomobject]@{ id = 'u9' }))
            , @('emailThresholdSettings$', [pscustomobject]@{ isEnabled = $true })
            , @('^users/u1$', $script:Alice)
            , @('^users/u3$', $Disabled)
            , @('^users/u9$', 'throw:Request_ResourceNotFound')
        )
        Test-MPAIGOV1026 | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Severity -eq 'Medium' -and $Result -match 'Only 1 alert recipient' -and
            $Result -match 'carol@contoso.com.*Alert recipient is disabled' -and $Result -match 'u9.*no longer exists'
        }
    }

    It 'ignores disabled policies' {
        Set-AIGovGraphRoute @( , @('^copilot/costManagement/spendingPolicies$', @(New-AIGovPolicy -Id 'p1' -Name 'Off' -Status 'disabled')))
        Test-MPAIGOV1026 | Should -BeTrue
    }

    It 'skips with Error when no alert settings can be read' {
        Set-AIGovGraphRoute @(
            , @('^copilot/costManagement/spendingPolicies$', @($script:Policy))
            , @('emailThresholdSettings$', 'throw:Service unavailable')
        )
        Test-MPAIGOV1026 | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'Error' }
    }

    It 'skips with NotAuthorized on a 403' {
        Mock Invoke-MtGraphRequest { throw [System.Exception]::new('403 Forbidden') }
        Test-MPAIGOV1026 | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'NotAuthorized' }
    }
}
