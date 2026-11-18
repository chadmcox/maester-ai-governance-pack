BeforeAll {
    . "$PSScriptRoot/Support/Set-AIGovGraphRoute.ps1"
    . "$PSScriptRoot/../pack/helpers/ConvertTo-AIGovMarkdownCell.ps1"
    . "$PSScriptRoot/../pack/helpers/ConvertTo-AIGovMarkdownTable.ps1"
    . "$PSScriptRoot/../pack/tests/Test.MP.AIGOV.1040.ps1"
}

Describe 'Test-MPAIGOV1040' {
    BeforeEach {
        Mock Add-MtTestResultDetail {}
    }

    It 'passes with a container label and unique names (same child name under two parents is fine)' {
        Set-AIGovGraphRoute @(, @('sensitivityLabels', @(
                    @{ displayName = 'Confidential'; isEnabled = $true; applicableTo = 'email,file,site,unifiedGroup'; isDefault = $true; sublabels = @(@{ displayName = 'All Employees'; isEnabled = $true; applicableTo = 'file' }) },
                    @{ displayName = 'Highly Confidential'; isEnabled = $true; applicableTo = 'email,file'; sublabels = @(@{ displayName = 'All Employees'; isEnabled = $true; applicableTo = 'file' }) }
                )))
        Test-MPAIGOV1040 | Should -Be $true
    }

    It 'fails Medium when no label applies to sites or groups' {
        Set-AIGovGraphRoute @(, @('sensitivityLabels', @(@{ displayName = 'General'; isEnabled = $true; applicableTo = 'email,teamwork,file' })))
        Test-MPAIGOV1040 | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Severity -eq 'Medium' -and $Result -match 'applies to sites or groups' }
    }

    It 'fails Low on a duplicate name only' {
        Set-AIGovGraphRoute @(, @('sensitivityLabels', @(
                    @{ displayName = 'Public'; isEnabled = $true; applicableTo = 'site'; isDefault = $true },
                    @{ displayName = 'public '; isEnabled = $true; applicableTo = 'file' }
                )))
        Test-MPAIGOV1040 | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Severity -eq 'Low' -and $Result -match 'Public \| 2' }
    }

    It 'fails Medium with no enabled labels' {
        Set-AIGovGraphRoute @(, @('sensitivityLabels', @(@{ displayName = 'Old'; isEnabled = $false; applicableTo = 'site' })))
        Test-MPAIGOV1040 | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Severity -eq 'Medium' -and $Result -match 'No enabled sensitivity labels' }
    }
}
