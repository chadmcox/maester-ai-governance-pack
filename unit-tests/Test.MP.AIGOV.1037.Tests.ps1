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

    It 'reads both the documented and the live AgentsInfo column spellings' {
        Mock Invoke-MtGraphSecurityQuery { @() }
        Test-MPAIGOV1037 | Should -Be $true
        Should -Invoke Invoke-MtGraphSecurityQuery -Times 1 -ParameterFilter {
            $Query -cmatch 'column_ifexists\("AgentName",\s*column_ifexists\("Name"' -and
            $Query -cmatch 'column_ifexists\("EntraAgentId",\s*column_ifexists\("EntraAgentID"' -and
            $Query -cmatch 'column_ifexists\("EntraBlueprintId",\s*column_ifexists\("EntraBlueprintID"' -and
            $Query -match '!in~\s*\("Deleted",\s*"Uninstalled",\s*"Blocked"\)'
        }
    }

    It 'does not count agents on excluded platforms or drafts, and says so' {
        Mock Invoke-MtGraphSecurityQuery {
            @(
                @{ AgentId = 'd4'; AgentName = 'Personal agent'; Platform = 'UserPlatform'; EntraAgentId = ''; EntraBlueprintId = ''; PublishedStatus = 'Published' },
                @{ AgentId = 'd5'; AgentName = 'Work in progress'; Platform = 'CopilotStudio'; EntraAgentId = ''; EntraBlueprintId = ''; PublishedStatus = 'Draft' },
                @{ AgentId = 'd6'; AgentName = 'Sales agent'; Platform = 'CopilotStudio'; EntraAgentId = 'sp6'; EntraBlueprintId = ''; PublishedStatus = 'Published' }
            )
        }
        Test-MPAIGOV1037 -ExcludedPlatforms 'UserPlatform' | Should -Be $true
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Result -match 'All 1 live cloud agent' -and
            $Result -match '1 draft agent' -and
            $Result -match '1 agent\(s\) on excluded platforms \(UserPlatform\)' -and
            $Result -match '\| UserPlatform \| 1 \| 0 \| 0 \| 0 \| 1 \| No \(excluded platform\) \|' -and
            $Result -match '\| CopilotStudio \| 2 \| 1 \| 1 \| 0 \| 1 \| Counted \|'
        }
    }

    It 'caps the listed rows at MaxRows and says how many more there are' {
        Mock Invoke-MtGraphSecurityQuery {
            1..5 | ForEach-Object { @{ AgentId = "d$_"; AgentName = "Agent $_"; Platform = 'AWSBedrock'; EntraAgentId = ''; EntraBlueprintId = '' } }
        }
        Test-MPAIGOV1037 -MaxRows 2 | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Result -match 'Found 5 of 5' -and
            $Result -match '\.\.\.and 3 more' -and
            $Result -match 'Agent 2' -and $Result -notmatch 'Agent 3 \|' -and
            $Result -match 'AIGOV\.ExcludedAgentPlatforms'
        }
    }

    It 'reports a query schema error instead of claiming the table or license is missing' {
        Mock Invoke-MtGraphSecurityQuery { throw "'project' operator: Failed to resolve scalar expression named 'AgentName'." }
        Test-MPAIGOV1037 | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'Error' -and $null -ne $SkippedError }
    }

    It 'skips NotAuthorized on 403' {
        Mock Invoke-MtGraphSecurityQuery { throw '403 Forbidden' }
        Test-MPAIGOV1037 | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'NotAuthorized' }
    }
}
