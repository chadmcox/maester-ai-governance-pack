# Dev-only Pester unit tests for Test-MPAIGOV1023. Not part of the installable pack.

BeforeAll {
    . "$PSScriptRoot/Support/Set-AIGovGraphRoute.ps1"
    . "$PSScriptRoot/../pack/helpers/ConvertTo-AIGovMarkdownCell.ps1"
    . "$PSScriptRoot/../pack/helpers/Test-AIGovUnclearName.ps1"
    . "$PSScriptRoot/../pack/helpers/Test-AIGovPoorDescription.ps1"
    . "$PSScriptRoot/../pack/tests/Test.MP.AIGOV.1023.ps1"
}

Describe 'Test-MPAIGOV1023' {
    BeforeEach { Mock Add-MtTestResultDetail { } }

    It 'passes for clear names and descriptions' {
        Set-AIGovGraphRoute @(
            , @('agentIdentity$', @([pscustomobject]@{ id = 'a1'; displayName = 'Expense Assistant (Microsoft Copilot Studio)' }))
            , @('agentIdentityBlueprint$', @([pscustomobject]@{ id = 'b1'; displayName = 'Expense Assistant'; description = 'Answers expense policy questions for Finance.' }))
        )
        Test-MPAIGOV1023 | Should -BeTrue
    }

    It 'flags unclear identity names and blueprint names and descriptions' {
        Set-AIGovGraphRoute @(
            , @('agentIdentity$', @([pscustomobject]@{ id = 'a1'; displayName = 'Test agent 2' }))
            , @('agentIdentityBlueprint$', @([pscustomobject]@{ id = 'b1'; displayName = 'Demo'; description = 'Demo' }))
        )
        Test-MPAIGOV1023 | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Severity -eq 'Medium' -and $Result -match 'Agent identity \| a1 \| Test agent 2 \| Unclear name' -and $Result -match 'Blueprint \| b1 \| Demo \| Unclear name; Poor description'
        }
    }

    It 'skips with NotAuthorized on a 403' {
        Mock Invoke-MtGraphRequest { throw [System.Exception]::new('403 Forbidden') }
        Test-MPAIGOV1023 | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'NotAuthorized' }
    }
}
