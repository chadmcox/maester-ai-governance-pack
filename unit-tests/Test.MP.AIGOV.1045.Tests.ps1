BeforeAll {
    . "$PSScriptRoot/../pack/helpers/ConvertTo-AIGovMarkdownCell.ps1"
    . "$PSScriptRoot/../pack/helpers/ConvertTo-AIGovMarkdownTable.ps1"
    . "$PSScriptRoot/../pack/tests/Test.MP.AIGOV.1045.ps1"
}

Describe 'Test-MPAIGOV1045' {
    BeforeEach {
        Mock Add-MtTestResultDetail {}
        Mock Invoke-MtAzureRequest { @{ properties = @{ pricingTier = 'Standard' } } }
    }

    It 'passes when there are no AI accounts' {
        Mock Invoke-MtAzureResourceGraphRequest { @() }
        Test-MPAIGOV1045 | Should -Be $true
    }

    It 'passes for a hardened account in a covered subscription' {
        Mock Invoke-MtAzureResourceGraphRequest { @(@{ name = 'aoai1'; kind = 'OpenAI'; subscriptionId = 's1'; resourceGroup = 'rg'; disableLocalAuth = $true; publicNetworkAccess = 'Disabled'; defaultAction = '' }) }
        Test-MPAIGOV1045 | Should -Be $true
    }

    It 'fails Medium for key auth, public access and Defender off' {
        Mock Invoke-MtAzureResourceGraphRequest { @(@{ name = 'aoai2'; kind = 'AIServices'; subscriptionId = 's2'; resourceGroup = 'rg'; disableLocalAuth = $null; publicNetworkAccess = 'Enabled'; defaultAction = 'Allow' }) }
        Mock Invoke-MtAzureRequest { @{ properties = @{ pricingTier = 'Free' } } }
        Test-MPAIGOV1045 | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Severity -eq 'Medium' -and $Result -match 'key auth allowed; public network access; Defender for AI Services off \(Free\)'
        }
    }

    It 'treats public access with a Deny default action as restricted' {
        Mock Invoke-MtAzureResourceGraphRequest { @(@{ name = 'aoai3'; kind = 'OpenAI'; subscriptionId = 's1'; resourceGroup = 'rg'; disableLocalAuth = $true; publicNetworkAccess = 'Enabled'; defaultAction = 'Deny' }) }
        Test-MPAIGOV1045 | Should -Be $true
    }

    It 'skips when Resource Graph fails' {
        Mock Invoke-MtAzureResourceGraphRequest { throw 'not connected' }
        Test-MPAIGOV1045 | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'Custom' }
    }
}
