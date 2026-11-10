BeforeAll {
    . "$PSScriptRoot/../pack/helpers/Get-AIGovPackageCatalogSkipMessage.ps1"
    . "$PSScriptRoot/../pack/helpers/Test-AIGovPackageUserAccessible.ps1"
    . "$PSScriptRoot/../pack/helpers/Test-AIGovCustomPackage.ps1"
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

    It 'fails High on a package whose elementTypes carry AgentConnectors but never the literal MCPServers string' {
        # Confirmed live (2026-11-10): some connector packages (e.g. LawQi, LegalZoom) have MCP server
        # data in their AgentConnectors detail even though their list-level elementTypes never include
        # the literal 'MCPServers' value -- filtering candidates on 'MCPServers' alone misses them.
        Mock Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'copilot/admin/catalog/packages' } {
            @(
                [pscustomobject]@{ id = 'pkg-1'; displayName = 'Connector-only MCP'; type = 'thirdParty'; elementTypes = @('DeclarativeCopilots', 'AgentConnectors', 'AgentSkills', 'ToolPlugins'); availableTo = 'allowedForAll'; deployedTo = 'acquiredForAll' }
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
                                            mcpServerUrl  = 'https://connector.example.com/mcp'
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

        $result = Test-MPAIGOV1016

        $result | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Severity -eq 'High' -and $Result -match 'pkg-1'
        }
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

    It 'fails High on None, and reports a missing authorization.type on a custom package distinctly as Unspecified' {
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

    It 'fails Medium, not High, when the only finding is a custom package with no authorization block' {
        Mock Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'copilot/admin/catalog/packages' } {
            @(
                [pscustomobject]@{ id = 'pkg-1'; displayName = 'Vendor MCP'; type = 'thirdParty'; elementTypes = @('MCPServers'); availableTo = 'allowedForSome'; deployedTo = 'acquiredForSome' }
            )
        }
        Mock Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'copilot/admin/catalog/packages/pkg-1' } {
            [pscustomobject]@{ elementDetails = @([pscustomobject]@{ elementType = 'AgentConnectors'; elements = @(
                [pscustomobject]@{ definition = (@{ toolSource = @{ remoteMcpServer = @{ mcpServerUrl = 'https://mcp.vendor.example/mcp' } } } | ConvertTo-Json -Depth 10) }
            ) }) }
        }

        Test-MPAIGOV1016 | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Severity -eq 'Medium' -and $Result -match 'Unspecified' }
    }

    It 'passes when a Microsoft first-party package has no authorization block (platform-authenticated)' {
        Mock Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'copilot/admin/catalog/packages' } {
            @(
                [pscustomobject]@{ id = 'pkg-1'; displayName = 'Sales'; type = 'firstParty'; publisher = 'Microsoft Corporation'; elementTypes = @('MCPServers'); availableTo = 'allowedForAll'; deployedTo = 'acquiredForAll' }
            )
        }
        Mock Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'copilot/admin/catalog/packages/pkg-1' } {
            [pscustomobject]@{ elementDetails = @([pscustomobject]@{ elementType = 'AgentConnectors'; elements = @(
                [pscustomobject]@{ definition = (@{ toolSource = @{ remoteMcpServer = @{ mcpServerUrl = 'https://agent365.svc.cloud.microsoft/mcp' } } } | ConvertTo-Json -Depth 10) }
            ) }) }
        }

        Test-MPAIGOV1016 | Should -Be $true
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Result -match 'Well done' -and $Result -match 'Unspecified' }
    }

    It 'still fails High when a Microsoft first-party package explicitly declares None' {
        Mock Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'copilot/admin/catalog/packages' } {
            @(
                [pscustomobject]@{ id = 'pkg-1'; displayName = 'MS anon'; type = 'firstParty'; elementTypes = @('MCPServers'); availableTo = 'allowedForSome'; deployedTo = 'acquiredForSome' }
            )
        }
        Mock Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'copilot/admin/catalog/packages/pkg-1' } {
            [pscustomobject]@{ elementDetails = @([pscustomobject]@{ elementType = 'AgentConnectors'; elements = @(
                [pscustomobject]@{ definition = (@{ toolSource = @{ remoteMcpServer = @{ mcpServerUrl = 'https://x.microsoft.com/mcp'; authorization = @{ type = 'None' } } } } | ConvertTo-Json -Depth 10) }
            ) }) }
        }

        Test-MPAIGOV1016 | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Severity -eq 'High' }
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

