BeforeAll {
    . "$PSScriptRoot/Support/Set-AIGovGraphRoute.ps1"
    . "$PSScriptRoot/../pack/helpers/ConvertTo-AIGovMarkdownCell.ps1"
    . "$PSScriptRoot/../pack/helpers/ConvertTo-AIGovMarkdownTable.ps1"
    . "$PSScriptRoot/../pack/tests/Test.MP.AIGOV.1036.ps1"

    $script:Identities = @(
        @{ id = 'ai1'; displayName = 'Expense agent'; appId = 'x1'; accountEnabled = $true },
        @{ id = 'ai2'; displayName = 'HR agent'; appId = 'x2'; accountEnabled = $true },
        @{ id = 'ai3'; displayName = 'Disabled agent'; appId = 'x3'; accountEnabled = $false }
    )
}

Describe 'Test-MPAIGOV1036' {
    BeforeEach {
        Mock Add-MtTestResultDetail {}
    }

    It 'passes when every enabled agent has an enabled user or a group sponsor' {
        Set-AIGovGraphRoute @(
            , @('^servicePrincipals/microsoft\.graph\.agentIdentity$', $Identities)
            , @('^servicePrincipals/ai1/', @(@{ '@odata.type' = '#microsoft.graph.user'; id = 'u1'; accountEnabled = $true }))
            , @('^servicePrincipals/ai2/', @(@{ '@odata.type' = '#microsoft.graph.group'; id = 'g1' }))
        )
        Test-MPAIGOV1036 | Should -Be $true
    }

    It 'fails Medium for no sponsor and for only disabled sponsors, and ignores disabled agents' {
        Set-AIGovGraphRoute @(
            , @('^servicePrincipals/microsoft\.graph\.agentIdentity$', $Identities)
            , @('^servicePrincipals/ai1/', @())
            , @('^servicePrincipals/ai2/', @(@{ '@odata.type' = '#microsoft.graph.user'; id = 'u1'; accountEnabled = $false }))
        )
        Test-MPAIGOV1036 | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Severity -eq 'Medium' -and $Result -match 'Expense agent .* no sponsor' -and $Result -match 'HR agent .* every sponsor is disabled' -and $Result -notmatch 'Disabled agent'
        }
    }

    It 'skips with an error when no sponsor list can be read' {
        Set-AIGovGraphRoute @(
            , @('^servicePrincipals/microsoft\.graph\.agentIdentity$', $Identities)
            , @('/sponsors$', 'throw:500 Internal Server Error')
        )
        Test-MPAIGOV1036 | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'Error' }
    }
}
