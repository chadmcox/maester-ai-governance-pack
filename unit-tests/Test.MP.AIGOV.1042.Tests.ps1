BeforeAll {
    . "$PSScriptRoot/Support/Set-AIGovGraphRoute.ps1"
    . "$PSScriptRoot/../pack/tests/Test.MP.AIGOV.1042.ps1"
}

Describe 'Test-MPAIGOV1042' {
    BeforeEach {
        Mock Add-MtTestResultDetail {}
    }

    It 'passes when web search is off (1)' {
        Set-AIGovGraphRoute @(, @('allowwebsearch', @{ id = 'microsoft.copilot.allowwebsearch'; value = '1' }))
        Test-MPAIGOV1042 | Should -Be $true
    }

    It 'passes with a note when web search is limited to Web mode (2)' {
        Set-AIGovGraphRoute @(, @('allowwebsearch', @{ value = '2' }))
        Test-MPAIGOV1042 | Should -Be $true
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Result -match 'Web mode' }
    }

    It 'fails Low when no tenant policy sets it' {
        Set-AIGovGraphRoute @(, @('allowwebsearch', @{ value = $null; policyId = $null }))
        Test-MPAIGOV1042 | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Severity -eq 'Low' -and $Result -match 'default applies' }
    }

    It 'skips NotAuthorized in an app-only run' {
        Set-AIGovGraphRoute @(, @('allowwebsearch', 'throw:403 Forbidden'))
        Test-MPAIGOV1042 | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'NotAuthorized' -and $Result -match 'delegated' }
    }

    It 'skips with a custom reason on tooManyGroupPolicies' {
        Set-AIGovGraphRoute @(, @('allowwebsearch', 'throw:502 Bad Gateway tooManyGroupPolicies'))
        Test-MPAIGOV1042 | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'Custom' }
    }
}
