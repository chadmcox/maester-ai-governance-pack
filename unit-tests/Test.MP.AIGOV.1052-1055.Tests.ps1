BeforeAll {
    . "$PSScriptRoot/../pack/helpers/ConvertTo-AIGovMarkdownCell.ps1"
    . "$PSScriptRoot/../pack/helpers/ConvertTo-AIGovMarkdownTable.ps1"
    . "$PSScriptRoot/../pack/helpers/Invoke-AIGovAzureList.ps1"
    . "$PSScriptRoot/../pack/tests/Test.MP.AIGOV.1052.ps1"
    . "$PSScriptRoot/../pack/tests/Test.MP.AIGOV.1053.ps1"
    . "$PSScriptRoot/../pack/tests/Test.MP.AIGOV.1054.ps1"
    . "$PSScriptRoot/../pack/tests/Test.MP.AIGOV.1055.ps1"

    function New-Risk([string]$Agent, [string]$Platform, [string]$Title, [string]$Severity, [bool]$HasOwners = $true) {
        [pscustomobject]@{ AgentId = [guid]::NewGuid().Guid; AgentName = $Agent; Platform = $Platform; PublishedStatus = 'Published'; HasOwners = $HasOwners; HasSourceId = $false; Title = $Title; Severity = $Severity }
    }
    function New-Mcp([string]$Agent, [string]$Published, [string]$Endpoint, [string]$Approval = '') {
        [pscustomobject]@{ AgentId = [guid]::NewGuid().Guid; AgentName = $Agent; Platform = 'Copilot Studio'; PublishedStatus = $Published; McpName = 'server'; McpType = 'http'; Endpoint = $Endpoint; Approval = $Approval }
    }
}

Describe 'Test-MPAIGOV1052' {
    BeforeEach { Mock Add-MtTestResultDetail {} }

    It 'passes when no indicator reaches the minimum severity' {
        Mock Invoke-MtGraphSecurityQuery { @((New-Risk 'Bot' 'Copilot Studio' 'Published Agent' 'Low')) }
        Test-MPAIGOV1052 | Should -Be $true
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Result -match '1 lower-severity' }
    }

    It 'fails Medium for High and Medium indicators, including local agents' {
        Mock Invoke-MtGraphSecurityQuery { @(
                (New-Risk 'Claude Desktop' 'LocalAgents' 'Running on a Device with Vulnerabilities' 'High'),
                (New-Risk 'Old bot' 'Copilot Studio' 'Dormant agent' 'Medium'),
                (New-Risk 'Bot' 'Copilot Studio' 'Published Agent' 'Low')
            ) }
        Test-MPAIGOV1052 | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Severity -eq 'Medium' -and $Result -match 'Found 2 agent' -and $Result -match 'Running on a Device with Vulnerabilities' -and $Result -match '1 lower-severity'
        }
    }

    It 'honors AIGOV.MinAgentRiskSeverity' {
        Mock Invoke-MtGraphSecurityQuery { @((New-Risk 'Old bot' 'Copilot Studio' 'Dormant agent' 'Medium')) }
        Test-MPAIGOV1052 -MinSeverity High | Should -Be $true
    }

    It 'leaves out catalog vendor agents and excluded platforms' {
        Mock Invoke-MtGraphSecurityQuery { @(
                (New-Risk 'Store agent' 'Other' 'Dormant agent' 'High' $false),
                (New-Risk 'Foundry bot' 'Foundry' 'Dormant agent' 'High')
            ) }
        Test-MPAIGOV1052 -ExcludedPlatforms 'Foundry' | Should -Be $true
    }

    It 'skips when AgentsInfo is missing' {
        Mock Invoke-MtGraphSecurityQuery { throw "Failed to resolve table expression named 'AgentsInfo'" }
        Test-MPAIGOV1052 | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'Custom' }
    }
}

Describe 'Test-MPAIGOV1053' {
    BeforeEach { Mock Add-MtTestResultDetail {} }

    It 'passes for HTTPS Microsoft hosts, including cloud.microsoft' {
        Mock Invoke-MtGraphSecurityQuery { @(
                (New-Mcp 'CLI' '' 'https://learn.microsoft.com/api/mcp'),
                (New-Mcp 'CLI' '' 'https://mcp.svc.cloud.microsoft/enterprise'),
                (New-Mcp 'Entra' 'Draft' '' 'always_allow')
            ) }
        Test-MPAIGOV1053 | Should -Be $true
    }

    It 'fails for plain HTTP, unlisted hosts and always_allow on a published agent, showing scheme and host only' {
        Mock Invoke-MtGraphSecurityQuery { @(
                (New-Mcp 'A' '' 'http://mcp.example.com/path?key=secret'),
                (New-Mcp 'B' 'Published' '' 'always_allow')
            ) }
        Test-MPAIGOV1053 | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Severity -eq 'Medium' -and $Result -match 'Found 2 of 2' -and $Result -match 'plain HTTP; host not on the allowlist' -and
            $Result -match 'runs tools without asking' -and $Result -match 'http://mcp.example.com' -and $Result -notmatch 'secret'
        }
    }

    It 'passes when Defender reports no MCP servers' {
        Mock Invoke-MtGraphSecurityQuery { @() }
        Test-MPAIGOV1053 | Should -Be $true
    }
}

Describe 'Test-MPAIGOV1054' {
    BeforeEach {
        Mock Add-MtTestResultDetail {}
        $script:Categories = @{ value = @('AuditLogs', 'RiskyAgents', 'AgentRiskEvents' | ForEach-Object { @{ name = $_; properties = @{ categoryType = 'Logs' } } }) }
    }

    It 'passes when both agent categories go to a workspace' {
        Mock Invoke-MtAzureRequest {
            if ($RelativeUri -match 'Categories') { return $script:Categories }
            @{ value = @(@{ properties = @{ workspaceId = 'w'; logs = @(@{ category = 'RiskyAgents'; enabled = $true }, @{ category = 'AgentRiskEvents'; enabled = $true }) } }) }
        }
        Test-MPAIGOV1054 | Should -Be $true
    }

    It 'fails Medium when an offered category is not exported' {
        Mock Invoke-MtAzureRequest {
            if ($RelativeUri -match 'Categories') { return $script:Categories }
            @{ value = @(@{ properties = @{ workspaceId = 'w'; logs = @(@{ category = 'AuditLogs'; enabled = $true }, @{ category = 'RiskyAgents'; enabled = $true }) } }) }
        }
        Test-MPAIGOV1054 | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Severity -eq 'Medium' -and $Result -match 'AgentRiskEvents \| Not exported' -and $Result -match 'RiskyAgents \| Exported' }
    }

    It 'does not fail for a category the tenant does not offer' {
        Mock Invoke-MtAzureRequest {
            if ($RelativeUri -match 'Categories') { return @{ value = @(@{ name = 'AuditLogs'; properties = @{ categoryType = 'Logs' } }) } }
            @{ value = @() }
        }
        Test-MPAIGOV1054 | Should -Be $true
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Result -match 'Not offered in this tenant' }
    }

    It 'skips as not authorized on 403' {
        Mock Invoke-MtAzureRequest { $null }
        Test-MPAIGOV1054 | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'NotAuthorized' }
    }
}

Describe 'Test-MPAIGOV1055' {
    BeforeEach { Mock Add-MtTestResultDetail {} }

    It 'fails Medium for auto-approve and untrusted processes' {
        Mock Invoke-MtGraphSecurityQuery { @(
                [pscustomobject]@{ Agent = 'Claude Code'; Vendor = 'Anthropic'; Version = '2'; Device = 'dev1'; Account = 'u1'; AutoApprove = 'true'; TrustedProcess = 'true' },
                [pscustomobject]@{ Agent = 'Tool'; Vendor = 'X'; Version = '1'; Device = 'dev2'; Account = 'u2'; AutoApprove = 'false'; TrustedProcess = 'false' },
                [pscustomobject]@{ Agent = 'Copilot CLI'; Vendor = 'GitHub'; Version = '1'; Device = 'dev1'; Account = 'u1'; AutoApprove = 'false'; TrustedProcess = 'true' }
            ) }
        Test-MPAIGOV1055 | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Severity -eq 'Medium' -and $Result -match 'Found 2 of 3' -and $Result -match 'acts without asking' -and $Result -match 'host process isn'
        }
    }

    It 'passes and notes agents with neither setting' {
        Mock Invoke-MtGraphSecurityQuery { @(
                [pscustomobject]@{ Agent = 'Copilot CLI'; AutoApprove = 'false'; TrustedProcess = 'true' },
                [pscustomobject]@{ Agent = 'Ollama'; AutoApprove = ''; TrustedProcess = '' }
            ) }
        Test-MPAIGOV1055 | Should -Be $true
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Result -match "1 local agent\(s\) reported neither" }
    }

    It 'passes when there are no local agents' {
        Mock Invoke-MtGraphSecurityQuery { @() }
        Test-MPAIGOV1055 | Should -Be $true
    }
}
