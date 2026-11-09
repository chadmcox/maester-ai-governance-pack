BeforeAll {
    . "$PSScriptRoot/../pack/helpers/Get-AIGovPackageCatalogSkipMessage.ps1"
    . "$PSScriptRoot/../pack/helpers/Test-AIGovPackageUserAccessible.ps1"
    . "$PSScriptRoot/../pack/tests/Test.MP.AIGOV.1016.ps1"
}

Describe 'Test-MPAIGOV1016' {
    BeforeEach {
        Mock Add-MtTestResultDetail {}
    }

    It 'passes when no package has an MCP server element' {
        Mock Invoke-MtGraphRequest {
            @(
                [pscustomobject]@{ id = 'pkg-1'; displayName = 'Not MCP'; elementTypes = @('App'); availableTo = 'allowedForSelected'; deployedTo = 'acquiredForSelected' }
            )
        }

        $result = Test-MPAIGOV1016

        $result | Should -Be $true
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Severity -eq $null }
    }

    It 'passes when every observed MCP server uses OAuth/Entra authorization' {
        Mock Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'copilot/admin/catalog/packages' } {
            @(
                [pscustomobject]@{ id = 'pkg-1'; displayName = 'Good MCP'; elementTypes = @('MCPServers'); availableTo = 'allowedForSelected'; deployedTo = 'acquiredForSelected' }
            )
        }
        Mock Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'copilot/admin/catalog/packages/pkg-1' } {
            [pscustomobject]@{
                elementDetails = @(
                    [pscustomobject]@{
                        elementType = 'AgentConnectors'
                        elements    = @(
                            [pscustomobject]@{
                                definition = (@{
                                    toolSource = @{
                                        remoteMcpServer = @{
                                            mcpServerUrl  = 'https://good.example.com/mcp'
                                            authorization = @{ type = 'OAuthPluginVault' }
                                        }
                                    }
                                } | ConvertTo-Json -Depth 10)
                            }
                        )
                    }
                )
            }
        }

        $result = Test-MPAIGOV1016

        $result | Should -Be $true
    }

    It 'fails High on a missing/unspecified authorization.type, reported distinctly from None' {
        Mock Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'copilot/admin/catalog/packages' } {
            @(
                [pscustomobject]@{ id = 'pkg-1'; displayName = 'Anonymous MCP'; elementTypes = @('MCPServers'); availableTo = 'allowedForAll'; deployedTo = 'acquiredForAll' }
                [pscustomobject]@{ id = 'pkg-2'; displayName = 'Malformed MCP'; elementTypes = @('MCPServers'); availableTo = 'allowedForSelected'; deployedTo = 'acquiredForSelected' }
            )
        }
        Mock Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'copilot/admin/catalog/packages/pkg-1' } {
            [pscustomobject]@{
                elementDetails = @(
                    [pscustomobject]@{
                        elementType = 'AgentConnectors'
                        elements    = @(
                            [pscustomobject]@{
                                definition = (@{
                                    toolSource = @{
                                        remoteMcpServer = @{
                                            mcpServerUrl  = 'https://anon.example.com/mcp'
                                            authorization = @{ type = 'None' }
                                        }
                                    }
                                } | ConvertTo-Json -Depth 10)
                            }
                        )
                    }
                )
            }
        }
        Mock Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'copilot/admin/catalog/packages/pkg-2' } {
            [pscustomobject]@{
                elementDetails = @(
                    [pscustomobject]@{
                        elementType = 'AgentConnectors'
                        elements    = @(
                            [pscustomobject]@{
                                definition = (@{
                                    toolSource = @{
                                        remoteMcpServer = @{
                                            mcpServerUrl = 'https://malformed.example.com/mcp'
                                        }
                                    }
                                } | ConvertTo-Json -Depth 10)
                            }
                        )
                    }
                )
            }
        }

        $result = Test-MPAIGOV1016

        $result | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Severity -eq 'High' -and
            $Result -match 'None' -and
            $Result -match 'Unspecified' -and
            $Result -match 'pkg-1' -and
            $Result -match 'pkg-2'
        }
    }

    It 'skips with Error when every MCP package detail call fails' {
        Mock Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'copilot/admin/catalog/packages' } {
            @(
                [pscustomobject]@{ id = 'pkg-1'; displayName = 'Broken'; elementTypes = @('MCPServers'); availableTo = 'allowedForSelected'; deployedTo = 'acquiredForSelected' }
            )
        }
        Mock Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'copilot/admin/catalog/packages/pkg-1' } {
            throw 'Simulated detail-call failure'
        }

        $result = Test-MPAIGOV1016

        $result | Should -Be $null
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'Error' }
    }

    It 'skips with NotAuthorized on a 403 from the list call' {
        Mock Invoke-MtGraphRequest { throw 'Request failed: 403 Forbidden' }

        $result = Test-MPAIGOV1016

        $result | Should -Be $null
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'NotAuthorized' }
    }
}

