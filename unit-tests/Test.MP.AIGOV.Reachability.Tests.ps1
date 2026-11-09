# Dev-only Pester unit tests: the connector checks (MP.AIGOV.1007, 1008, 1010, 1011) only report on
# packages users can reach. Blocked packages and packages allowed for no one are skipped.
# Not part of the installable pack.

BeforeAll {
    . "$PSScriptRoot/Support/Set-AIGovGraphRoute.ps1"
    . "$PSScriptRoot/../pack/helpers/Get-AIGovPackageCatalogSkipMessage.ps1"
    . "$PSScriptRoot/../pack/helpers/Test-AIGovPackageUserAccessible.ps1"
    . "$PSScriptRoot/../pack/tests/Test.MP.AIGOV.1007.ps1"
    . "$PSScriptRoot/../pack/tests/Test.MP.AIGOV.1008.ps1"
    . "$PSScriptRoot/../pack/tests/Test.MP.AIGOV.1010.ps1"
    . "$PSScriptRoot/../pack/tests/Test.MP.AIGOV.1011.ps1"

    function New-McpDetail([string]$Url, [switch]$OpenWorld) {
        $Tool = @{ name = 'search'; annotations = @{ openWorldHint = [bool]$OpenWorld } }
        [pscustomobject]@{
            elementDetails = @(
                [pscustomobject]@{
                    elementType = 'AgentConnectors'
                    elements    = @(
                        [pscustomobject]@{
                            definition = (@{
                                    toolSource = @{ remoteMcpServer = @{ mcpServerUrl = $Url; mcpToolDescription = @{ tools = @($Tool) } } }
                                } | ConvertTo-Json -Depth 10)
                        }
                    )
                }
            )
        }
    }

    # p1 is reachable; p2 is blocked; p3 is allowed for no one. All three are equally bad, so only
    # p1 should ever appear in a finding.
    $script:Catalog = @(
        [pscustomobject]@{ id = 'p1'; displayName = 'Reachable MCP'; type = 'thirdParty'; publisher = 'Vendor'; elementTypes = @('MCPServers', 'AgentConnectors'); availableTo = 'allowedForAll'; deployedTo = 'acquiredForAll'; isBlocked = $false }
        [pscustomobject]@{ id = 'p2'; displayName = 'Blocked MCP'; type = 'thirdParty'; publisher = 'Vendor'; elementTypes = @('MCPServers', 'AgentConnectors'); availableTo = 'allowedForAll'; deployedTo = 'acquiredForAll'; isBlocked = $true }
        [pscustomobject]@{ id = 'p3'; displayName = 'Nobody MCP'; type = 'thirdParty'; publisher = 'Vendor'; elementTypes = @('MCPServers', 'AgentConnectors'); availableTo = 'allowedForNone'; deployedTo = 'acquiredForAll'; isBlocked = $false }
    )
}

Describe 'Connector checks skip packages users cannot reach' {
    BeforeEach { Mock Add-MtTestResultDetail { } }

    It 'MP.AIGOV.1008 reports only the reachable plain-HTTP server and counts the skipped ones' {
        Set-AIGovGraphRoute @(
            , @('^copilot/admin/catalog/packages$', $script:Catalog)
            , @('^copilot/admin/catalog/packages/p1$', (New-McpDetail 'http://one.example.com/mcp'))
            , @('^copilot/admin/catalog/packages/p[23]$', (New-McpDetail 'http://two.example.com/mcp'))
        )
        Test-MPAIGOV1008 | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Result -match 'Found 1 MCP server endpoint' -and $Result -match 'Reachable MCP' -and
            $Result -notmatch 'Blocked MCP' -and $Result -notmatch 'Nobody MCP' -and $Result -match '2 blocked or allowed-for-no-one'
        }
        Should -Invoke Invoke-MtGraphRequest -Times 0 -ParameterFilter { [string]$RelativeUri[0] -match 'packages/p[23]$' }
    }

    It 'MP.AIGOV.1008 passes when the only bad server is blocked' {
        Set-AIGovGraphRoute @(
            , @('^copilot/admin/catalog/packages$', @($script:Catalog[1]))
        )
        Test-MPAIGOV1008 | Should -BeTrue
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Result -match 'Well done' -and $Result -match '1 blocked' }
    }

    It 'MP.AIGOV.1010 reports only the reachable off-allowlist server' {
        Set-AIGovGraphRoute @(
            , @('^copilot/admin/catalog/packages$', $script:Catalog)
            , @('^copilot/admin/catalog/packages/p\d$', (New-McpDetail 'https://mcp.vendor.example/mcp'))
        )
        Test-MPAIGOV1010 | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Result -match 'Found 1 MCP server endpoint' -and $Result -notmatch 'Blocked MCP' -and $Result -notmatch 'Nobody MCP'
        }
    }

    It 'MP.AIGOV.1011 ignores a blocked package still marked available to everyone' {
        Set-AIGovGraphRoute @(
            , @('^copilot/admin/catalog/packages$', $script:Catalog)
            , @('^copilot/admin/catalog/packages/p\d$', (New-McpDetail 'https://mcp.vendor.example/mcp' -OpenWorld))
        )
        Test-MPAIGOV1011 | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Result -match 'Found 1 MCP tool' -and $Result -match 'Reachable MCP' -and $Result -notmatch 'Blocked MCP'
        }
    }

    It 'MP.AIGOV.1007 ignores a blocked custom package available to everyone' {
        Set-AIGovGraphRoute @(
            , @('^copilot/admin/catalog/packages$', @($script:Catalog[1]))
        )
        Test-MPAIGOV1007 | Should -BeTrue
    }

    It 'MP.AIGOV.1007 still flags a reachable custom package available to everyone' {
        Set-AIGovGraphRoute @(
            , @('^copilot/admin/catalog/packages$', @($script:Catalog[0]))
        )
        Test-MPAIGOV1007 | Should -BeFalse
    }
}
