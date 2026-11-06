BeforeAll {
    . "$PSScriptRoot/../pack/tests/Test.MP.AIGOV.1018.ps1"
}

Describe 'Test-MPAIGOV1018' {
    BeforeEach {
        Mock Add-MtTestResultDetail {}
    }

    It 'passes when no agent identity is at risk or confirmed compromised' {
        Mock Invoke-MtGraphRequest {
            @(
                [pscustomobject]@{ id = 'agent-1'; agentDisplayName = 'Safe agent'; riskState = 'confirmedSafe'; riskLevel = 'low'; isEnabled = $true; isDeleted = $false }
                [pscustomobject]@{ id = 'agent-2'; agentDisplayName = 'Dismissed agent'; riskState = 'dismissed'; riskLevel = 'medium'; isEnabled = $true; isDeleted = $false }
            )
        }

        $result = Test-MPAIGOV1018

        $result | Should -Be $true
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Severity -eq $null }
    }

    It 'fails High and lists both atRisk and confirmedCompromised agents' {
        Mock Invoke-MtGraphRequest {
            @(
                [pscustomobject]@{ id = 'agent-1'; agentDisplayName = 'At risk agent'; riskState = 'atRisk'; riskLevel = 'high'; isEnabled = $true; isDeleted = $false }
                [pscustomobject]@{ id = 'agent-2'; agentDisplayName = 'Compromised agent'; riskState = 'confirmedCompromised'; riskLevel = 'high'; isEnabled = $true; isDeleted = $false }
            )
        }

        $result = Test-MPAIGOV1018

        $result | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Severity -eq 'High' -and $Result -match 'agent-1' -and $Result -match 'agent-2'
        }
    }

    It 'skips with NotAuthorized on a 403 and mentions the Agent 365 license' {
        Mock Invoke-MtGraphRequest { throw 'Request failed: 403 Forbidden' }

        $result = Test-MPAIGOV1018

        $result | Should -Be $null
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $SkippedBecause -eq 'NotAuthorized' -and $Result -match '(?i)Agent 365'
        }
    }

    It 'skips with a distinct Error message when the endpoint is not found (not yet rolled out)' {
        Mock Invoke-MtGraphRequest { throw 'Request failed: 404 Not Found' }

        $result = Test-MPAIGOV1018

        $result | Should -Be $null
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $SkippedBecause -eq 'Error' -and $Result -match '(?i)not yet'
        }
    }

    It 'skips with the generic Error path for an unrelated failure' {
        Mock Invoke-MtGraphRequest { throw 'Simulated transient failure' }

        $result = Test-MPAIGOV1018

        $result | Should -Be $null
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $SkippedBecause -eq 'Error' -and $null -ne $SkippedError
        }
    }
}

