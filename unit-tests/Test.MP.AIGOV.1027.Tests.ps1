# Dev-only Pester unit tests for Test-MPAIGOV1027. Not part of the installable pack.

BeforeAll {
    . "$PSScriptRoot/Support/Set-AIGovGraphRoute.ps1"
    . "$PSScriptRoot/../pack/helpers/Get-AIGovCostManagementSkipMessage.ps1"
    . "$PSScriptRoot/../pack/helpers/ConvertTo-AIGovMarkdownCell.ps1"
    . "$PSScriptRoot/../pack/helpers/Test-AIGovNotFoundError.ps1"
    . "$PSScriptRoot/../pack/tests/Test.MP.AIGOV.1027.ps1"

    $script:Policy = New-AIGovPolicy -Id 'p1' -Name 'Pilot'
    function Get-GroupRoutes([object]$Group, [object[]]$Nested = @(), [object[]]$Members = @([pscustomobject]@{ id = 'u1' })) {
        @(
            , @('^copilot/costManagement/spendingPolicies$', @($script:Policy))
            , @('assignedGroups$', @([pscustomobject]@{ id = 'g1' }))
            , @('^groups/g1/members/microsoft\.graph\.group$', $Nested)
            , @('^groups/g1/members$', $Members)
            , @('^groups/g1$', $Group)
        )
    }
}

Describe 'Test-MPAIGOV1027' {
    BeforeEach { Mock Add-MtTestResultDetail { } }

    It 'passes for a populated, assigned security group' {
        Set-AIGovGraphRoute (Get-GroupRoutes ([pscustomobject]@{ id = 'g1'; displayName = 'Pilot'; groupTypes = @(); securityEnabled = $true }))
        Test-MPAIGOV1027 | Should -BeTrue
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Result -match 'Well done' }
    }

    It 'flags a Microsoft 365 group, nesting and an empty group' {
        Set-AIGovGraphRoute (Get-GroupRoutes `
            ([pscustomobject]@{ id = 'g1'; displayName = 'Team'; groupTypes = @('Unified'); securityEnabled = $false }) `
            @([pscustomobject]@{ id = 'g2'; displayName = 'Inner' }) @())
        Test-MPAIGOV1027 | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Severity -eq 'Medium' -and $Result -match 'Microsoft 365 group' -and $Result -match 'nested groups: Inner' -and $Result -match 'Group is empty'
        }
    }

    It 'passes with an Info note for a dynamic security group' {
        Set-AIGovGraphRoute (Get-GroupRoutes ([pscustomobject]@{ id = 'g1'; displayName = 'All sales'; groupTypes = @('DynamicMembership'); securityEnabled = $true }))
        Test-MPAIGOV1027 | Should -BeTrue
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Severity -eq 'Info' -and $Result -match 'Dynamic group' }
    }

    It 'leaves a deleted group to MP.AIGOV.1025' {
        Set-AIGovGraphRoute @(
            , @('^copilot/costManagement/spendingPolicies$', @($script:Policy))
            , @('assignedGroups$', @([pscustomobject]@{ id = 'g1' }))
            , @('^groups/g1', 'throw:404 Not Found')
        )
        Test-MPAIGOV1027 | Should -BeTrue
    }

    It 'skips with Error when no assigned groups can be read' {
        Set-AIGovGraphRoute @(
            , @('^copilot/costManagement/spendingPolicies$', @($script:Policy))
            , @('assignedGroups$', 'throw:Service unavailable')
        )
        Test-MPAIGOV1027 | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'Error' }
    }

    It 'skips with NotAuthorized on a 403' {
        Mock Invoke-MtGraphRequest { throw [System.Exception]::new('403 Forbidden') }
        Test-MPAIGOV1027 | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'NotAuthorized' }
    }

    # Regression: confirmed live against the test tenant that $select=id alone on this beta
    # navigation property 404s, even though the exact same request with two or more fields succeeds.
    It 'asks for more than just id when reading assignedGroups' {
        Set-AIGovGraphRoute (Get-GroupRoutes ([pscustomobject]@{ id = 'g1'; displayName = 'Pilot'; groupTypes = @(); securityEnabled = $true }))
        Test-MPAIGOV1027 | Should -BeTrue
        Should -Invoke Invoke-MtGraphRequest -ParameterFilter {
            ([string]$RelativeUri[0]) -match 'assignedGroups$' -and @($Select).Count -gt 1 -and $Select -contains 'id'
        }
    }
}
