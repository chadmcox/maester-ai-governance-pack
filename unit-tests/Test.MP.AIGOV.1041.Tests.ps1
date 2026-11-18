BeforeAll {
    . "$PSScriptRoot/Support/Set-AIGovGraphRoute.ps1"
    . "$PSScriptRoot/../pack/helpers/ConvertTo-AIGovMarkdownCell.ps1"
    . "$PSScriptRoot/../pack/helpers/ConvertTo-AIGovMarkdownTable.ps1"
    . "$PSScriptRoot/../pack/tests/Test.MP.AIGOV.1041.ps1"

    $script:Tenant = '00000000-0000-0000-0000-00000000aaaa'
}

Describe 'Test-MPAIGOV1041' {
    BeforeEach {
        Mock Add-MtTestResultDetail {}
    }

    It 'passes when the only foreign blueprint has a verified publisher; own and Microsoft blueprints are ignored' {
        Set-AIGovGraphRoute @(
            , @('^organization$', @(@{ id = $Tenant }))
            , @('agentIdentityBlueprintPrincipal', @(
                    @{ id = 's1'; displayName = 'Ours'; appId = 'a1'; appOwnerOrganizationId = $Tenant },
                    @{ id = 's2'; displayName = 'Microsoft'; appId = 'a2'; appOwnerOrganizationId = 'f8cdef31-a31e-4b4a-93e4-5f571e91255a' },
                    @{ id = 's3'; displayName = 'Vendor'; appId = 'a3'; appOwnerOrganizationId = 'vendor-tenant'; verifiedPublisher = @{ verifiedPublisherId = '123' } }
                ))
        )
        Test-MPAIGOV1041 | Should -Be $true
    }

    It 'fails Medium for a foreign blueprint with no verified publisher' {
        Set-AIGovGraphRoute @(
            , @('^organization$', @(@{ id = $Tenant }))
            , @('agentIdentityBlueprintPrincipal', @(
                    @{ id = 's3'; displayName = 'Unknown vendor'; appId = 'a3'; appOwnerOrganizationId = 'vendor-tenant'; verifiedPublisher = @{ verifiedPublisherId = $null } }
                ))
        )
        Test-MPAIGOV1041 | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Severity -eq 'Medium' -and $Result -match 'Unknown vendor \| a3 \| vendor-tenant' }
    }
}
