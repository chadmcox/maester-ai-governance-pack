BeforeAll {
    . "$PSScriptRoot/Support/Set-AIGovGraphRoute.ps1"
    . "$PSScriptRoot/../pack/helpers/ConvertTo-AIGovMarkdownCell.ps1"
    . "$PSScriptRoot/../pack/helpers/ConvertTo-AIGovMarkdownTable.ps1"
    . "$PSScriptRoot/../pack/helpers/ConvertTo-AIGovUtcDate.ps1"
    . "$PSScriptRoot/../pack/tests/Test.MP.AIGOV.1035.ps1"

    $script:Future = [datetime]::UtcNow.AddDays(200).ToString('o')
    $script:Past = [datetime]::UtcNow.AddDays(-5).ToString('o')
}

Describe 'Test-MPAIGOV1035' {
    BeforeEach {
        Mock Add-MtTestResultDetail {}
    }

    It 'passes when no blueprint has an active secret' {
        Set-AIGovGraphRoute @(
            , @('^applications/microsoft\.graph\.agentIdentityBlueprint$', @(
                    @{ id = 'b1'; displayName = 'Cert only'; appId = 'a1'; passwordCredentials = @(); keyCredentials = @(@{ keyId = 'k1' }) },
                    @{ id = 'b2'; displayName = 'Expired secret'; appId = 'a2'; passwordCredentials = @(@{ endDateTime = $Past }); keyCredentials = @() }
                ))
        )
        Test-MPAIGOV1035 | Should -Be $true
    }

    It 'fails Medium for an active secret and reports federated credential count' {
        Set-AIGovGraphRoute @(
            , @('^applications/microsoft\.graph\.agentIdentityBlueprint$', @(
                    @{ id = 'b1'; displayName = 'Secret blueprint'; appId = 'a1'; passwordCredentials = @(@{ endDateTime = $Future }); keyCredentials = @() }
                ))
            , @('^applications/b1/federatedIdentityCredentials$', @(@{ id = 'f1' }))
        )
        Test-MPAIGOV1035 | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Severity -eq 'Medium' -and $Result -match 'Secret blueprint \| a1 \| 1 \| 0 \| 1'
        }
    }

    It 'reports unknown when federated credentials cannot be read' {
        Set-AIGovGraphRoute @(
            , @('^applications/microsoft\.graph\.agentIdentityBlueprint$', @(
                    @{ id = 'b1'; displayName = 'Secret blueprint'; appId = 'a1'; passwordCredentials = @(@{ endDateTime = $Future }); keyCredentials = @() }
                ))
            , @('federatedIdentityCredentials', 'throw:404 Not Found')
        )
        Test-MPAIGOV1035 | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Result -match '\| unknown \|' }
    }

    It 'skips NotAuthorized on 403' {
        Set-AIGovGraphRoute @(, @('agentIdentityBlueprint', 'throw:403 Forbidden'))
        Test-MPAIGOV1035 | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'NotAuthorized' }
    }
}
