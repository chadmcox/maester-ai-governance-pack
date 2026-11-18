BeforeAll {
    . "$PSScriptRoot/../pack/helpers/ConvertTo-AIGovMarkdownCell.ps1"
    . "$PSScriptRoot/../pack/helpers/ConvertTo-AIGovMarkdownTable.ps1"
    . "$PSScriptRoot/../pack/tests/Test.MP.AIGOV.1037.ps1"
}

Describe 'Test-MPAIGOV1037' {
    BeforeEach {
        Mock Add-MtTestResultDetail {}
    }

    It 'passes when every cloud agent has an Entra ID and reports local agents for information' {
        Mock Invoke-MtGraphSecurityQuery {
            @(
                @{ AgentId = 'd1'; AgentName = 'Sales agent'; Platform = 'CopilotStudio'; EntraAgentId = 'sp1'; EntraBlueprintId = '' },
                @{ AgentId = 'd2'; AgentName = 'Coding agent'; Platform = 'LocalAgents'; EntraAgentId = ''; EntraBlueprintId = '' }
            )
        }
        Test-MPAIGOV1037 | Should -Be $true
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Result -match '1 local agent' }
    }

    It 'fails Medium for a cloud agent with neither Entra ID' {
        Mock Invoke-MtGraphSecurityQuery {
            @(@{ AgentId = 'd3'; AgentName = 'Shadow agent'; Platform = 'AWSBedrock'; EntraAgentId = $null; EntraBlueprintId = $null })
        }
        Test-MPAIGOV1037 | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Severity -eq 'Medium' -and $Result -match 'Shadow agent \| AWSBedrock \| d3' }
    }

    It 'skips with a custom reason when the AgentsInfo table is missing' {
        Mock Invoke-MtGraphSecurityQuery { throw "Failed to resolve table or column expression named 'AgentsInfo'" }
        Test-MPAIGOV1037 | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'Custom' -and $SkippedCustomReason -match 'Agent 365' }
    }

    It 'skips NotAuthorized on 403' {
        Mock Invoke-MtGraphSecurityQuery { throw '403 Forbidden' }
        Test-MPAIGOV1037 | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'NotAuthorized' }
    }
}
