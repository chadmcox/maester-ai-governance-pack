BeforeAll {
    . "$PSScriptRoot/../pack/tests/Test.MP.AIGOV.1017.ps1"
}

Describe 'Test-MPAIGOV1017' {
    BeforeEach {
        Mock Add-MtTestResultDetail {}
    }

    It 'passes when an enabled policy uses a dynamic agentIdServicePrincipalFilter' {
        Mock Invoke-MtGraphRequest {
            @(
                [pscustomobject]@{
                    id          = 'policy-1'
                    displayName = 'Dynamic agent policy'
                    state       = 'enabled'
                    conditions  = [pscustomobject]@{
                        clientApplications = [pscustomobject]@{
                            includeAgentIdServicePrincipals = @()
                            agentIdServicePrincipalFilter   = [pscustomobject]@{ rule = "agentType eq 'all'" }
                        }
                        agentIdRiskLevels  = @()
                    }
                }
            )
        }

        $result = Test-MPAIGOV1017

        $result | Should -Be $true
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Severity -eq $null }
    }

    It 'passes when an enabled policy uses agentIdRiskLevels' {
        Mock Invoke-MtGraphRequest {
            @(
                [pscustomobject]@{
                    id          = 'policy-1'
                    displayName = 'Risk-based agent policy'
                    state       = 'enabled'
                    conditions  = [pscustomobject]@{
                        clientApplications = [pscustomobject]@{
                            includeAgentIdServicePrincipals = @()
                            agentIdServicePrincipalFilter   = $null
                        }
                        agentIdRiskLevels  = @('high')
                    }
                }
            )
        }

        $result = Test-MPAIGOV1017

        $result | Should -Be $true
    }

    It 'reports Partial (Medium) when the only enabled agent-targeting policy uses a static ID list' {
        Mock Invoke-MtGraphRequest {
            @(
                [pscustomobject]@{
                    id          = 'policy-1'
                    displayName = 'Static agent policy'
                    state       = 'enabled'
                    conditions  = [pscustomobject]@{
                        clientApplications = [pscustomobject]@{
                            includeAgentIdServicePrincipals = @('agent-sp-1', 'agent-sp-2')
                            agentIdServicePrincipalFilter   = $null
                        }
                        agentIdRiskLevels  = @()
                    }
                }
            )
        }

        $result = Test-MPAIGOV1017

        $result | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Severity -eq 'Medium' -and $Result -match 'Partial coverage' -and $Result -match 'policy-1'
        }
    }

    It 'fails High when no Conditional Access policy targets agent identities at all' {
        Mock Invoke-MtGraphRequest {
            @(
                [pscustomobject]@{
                    id          = 'policy-1'
                    displayName = 'Unrelated policy'
                    state       = 'enabled'
                    conditions  = [pscustomobject]@{
                        clientApplications = [pscustomobject]@{
                            includeAgentIdServicePrincipals = @()
                            agentIdServicePrincipalFilter   = $null
                        }
                        agentIdRiskLevels  = @()
                    }
                }
            )
        }

        $result = Test-MPAIGOV1017

        $result | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Severity -eq 'High' -and $Result -match 'no enabled policy targets agent'
        }
    }

    It 'fails High when agent-targeting policies exist but none is enabled' {
        Mock Invoke-MtGraphRequest {
            @(
                [pscustomobject]@{
                    id          = 'policy-1'
                    displayName = 'Report-only agent policy'
                    state       = 'enabledForReportingButNotEnforced'
                    conditions  = [pscustomobject]@{
                        clientApplications = [pscustomobject]@{
                            includeAgentIdServicePrincipals = @('agent-sp-1')
                            agentIdServicePrincipalFilter   = $null
                        }
                        agentIdRiskLevels  = @()
                    }
                }
            )
        }

        $result = Test-MPAIGOV1017

        $result | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Severity -eq 'High' -and $Result -match 'report-only or off'
        }
    }

    It 'skips with NotAuthorized on a 403' {
        Mock Invoke-MtGraphRequest { throw 'Request failed: 403 Forbidden' }

        $result = Test-MPAIGOV1017

        $result | Should -Be $null
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'NotAuthorized' }
    }
}

