# Dev-only Pester unit tests for Test-MPAIGOV1015 (pack/tests/Test.MP.AIGOV.1015.ps1).
# Not part of the installable pack: see unit-tests/Test.MP.AIGOV.1006.Tests.ps1 for why this folder
# lives outside pack/.

BeforeAll {
    # The Maester module (for the [MaesterTest()] attribute type) is imported once at the
    # CI/session level before Invoke-Pester runs -- see unit-tests/Test.MP.AIGOV.1006.Tests.ps1.
    . "$PSScriptRoot/../pack/helpers/Get-AIGovCostManagementSkipMessage.ps1"
    . "$PSScriptRoot/../pack/helpers/Get-AIGovSpendingLimit.ps1"
    . "$PSScriptRoot/../pack/helpers/Add-AIGovSpendingAudiencePolicy.ps1"
    . "$PSScriptRoot/../pack/helpers/ConvertTo-AIGovMarkdownCell.ps1"
    . "$PSScriptRoot/../pack/tests/Test.MP.AIGOV.1015.ps1"

    function New-Limit([object]$Value, [string]$Unit = 'credits') {
        if ($Value -eq 'unlimited') { return [pscustomobject]@{ '@odata.type' = '#microsoft.graph.unlimitedCostManagementQuantity' } }
        return [pscustomobject]@{ '@odata.type' = '#microsoft.graph.limitedCostManagementQuantity'; value = $Value; unit = $Unit }
    }

    function New-Policy([string]$Id, [string]$Name, [string]$Kind, [object]$PerUser, [string]$Status = 'enabled', [string]$Unit = 'credits') {
        $Type = if ($Kind -eq 'all') { '#microsoft.graph.allUsersSpendingPolicy' } else { '#microsoft.graph.selectedGroupsSpendingPolicy' }
        [pscustomobject]@{
            '@odata.type' = $Type; id = $Id; displayName = $Name; status = $Status
            periodLimit = New-Limit 'unlimited'; perUserLimit = New-Limit $PerUser $Unit
        }
    }

    # Mock Invoke-MtGraphRequest from a policy list and a policyId -> groups map.
    function Set-GraphMock([object[]]$Policies, [hashtable]$GroupsByPolicy) {
        $script:MockPolicies = $Policies
        $script:MockGroups = $GroupsByPolicy
        Mock Invoke-MtGraphRequest {
            # Invoke-MtGraphRequest declares -RelativeUri as [string[]], so even a single-URI call
            # binds an array here: compare the first element, not the array itself.
            $Uri = [string]$RelativeUri[0]
            if ($Uri -eq 'copilot/costManagement/spendingPolicies') { return $script:MockPolicies }
            if ($Uri -match 'spendingPolicies/([^/]+)/microsoft\.graph\.selectedGroupsSpendingPolicy/assignedGroups$') {
                $Id = $Matches[1]
                if ($script:MockGroups[$Id] -eq 'throw') { throw [System.Exception]::new('Service unavailable') }
                return @($script:MockGroups[$Id])
            }
            throw "Unexpected RelativeUri: $Uri"
        }
    }

    $GroupA = [pscustomobject]@{ id = 'g-a'; displayName = 'Copilot Pilot' }
}

Describe 'Test-MPAIGOV1015' {
    BeforeEach {
        Mock Add-MtTestResultDetail { }
    }

    It 'passes for normal tiering: a group tier more permissive than an all-users base policy' {
        Set-GraphMock @(
            (New-Policy 'p-base' 'Everyone base' 'all' 100),
            (New-Policy 'p-tier' 'Power users' 'groups' 1000)
        ) @{ 'p-tier' = @($GroupA) }

        Test-MPAIGOV1015 | Should -BeTrue
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Result -match 'Well done' }
    }

    It 'flags Medium when a group cap is overridden by a higher cap in another group policy' {
        Set-GraphMock @(
            (New-Policy 'p-low' 'Restricted' 'groups' 100),
            (New-Policy 'p-high' 'Generous' 'groups' 500)
        ) @{ 'p-low' = @($GroupA); 'p-high' = @($GroupA) }

        Test-MPAIGOV1015 | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Severity -eq 'Medium' -and $Result -match 'g-a' -and $Result -match '500 credits \(from Generous\)' -and $Result -match 'Restricted \(100 credits\)'
        }
    }

    It 'flags High when a group cap is overridden by an unlimited all-users policy' {
        Set-GraphMock @(
            (New-Policy 'p-base' 'Everyone' 'all' 'unlimited'),
            (New-Policy 'p-tier' 'Contractors' 'groups' 50)
        ) @{ 'p-tier' = @($GroupA) }

        Test-MPAIGOV1015 | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Severity -eq 'High' -and $Result -match 'Unlimited \(from Everyone\)' -and $Result -match 'Contractors \(50 credits\)'
        }
    }

    It 'flags Low for a redundant overlap with the same limit' {
        Set-GraphMock @(
            (New-Policy 'p-1' 'Policy one' 'groups' 200),
            (New-Policy 'p-2' 'Policy two' 'groups' 200)
        ) @{ 'p-1' = @($GroupA); 'p-2' = @($GroupA) }

        Test-MPAIGOV1015 | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Severity -eq 'Low' -and $Result -match 'Redundant overlap' }
    }

    It 'compares two enabled all-users policies with each other' {
        Set-GraphMock @(
            (New-Policy 'p-a' 'All users A' 'all' 100),
            (New-Policy 'p-b' 'All users B' 'all' 300)
        ) @{}

        Test-MPAIGOV1015 | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Severity -eq 'Medium' -and $Result -match 'All users' -and $Result -match 'All users A \(100 credits\)' }
    }

    It 'reports Low "cannot determine" when units differ' {
        Set-GraphMock @(
            (New-Policy 'p-1' 'Credits policy' 'groups' 100 -Unit 'credits'),
            (New-Policy 'p-2' 'Other unit policy' 'groups' 100 -Unit 'usd')
        ) @{ 'p-1' = @($GroupA); 'p-2' = @($GroupA) }

        Test-MPAIGOV1015 | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Severity -eq 'Low' -and $Result -match 'Cannot determine' }
    }

    It 'ignores disabled policies' {
        Set-GraphMock @(
            (New-Policy 'p-low' 'Restricted' 'groups' 100),
            (New-Policy 'p-off' 'Disabled generous' 'groups' 'unlimited' -Status 'disabled')
        ) @{ 'p-low' = @($GroupA); 'p-off' = @($GroupA) }

        Test-MPAIGOV1015 | Should -BeTrue
    }

    It 'escapes markdown in group names' {
        $Evil = [pscustomobject]@{ id = 'g-x'; displayName = "Bad | name`n<script>" }
        Set-GraphMock @(
            (New-Policy 'p-low' 'Low' 'groups' 1),
            (New-Policy 'p-high' 'High' 'groups' 2)
        ) @{ 'p-low' = @($Evil); 'p-high' = @($Evil) }

        Test-MPAIGOV1015 | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Result -match 'Bad &#124; name &lt;script&gt;' -and $Result -notmatch '<script>'
        }
    }

    It 'reports unreadable policies but still evaluates the rest' {
        Set-GraphMock @(
            (New-Policy 'p-ok-1' 'One' 'groups' 100),
            (New-Policy 'p-ok-2' 'Two' 'groups' 500),
            (New-Policy 'p-bad' 'Broken' 'groups' 100)
        ) @{ 'p-ok-1' = @($GroupA); 'p-ok-2' = @($GroupA); 'p-bad' = 'throw' }

        Test-MPAIGOV1015 | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Result -match '1 group-scoped policy\(ies\) could not be read' }
    }

    It 'skips with Error when no group policy can be read' {
        Set-GraphMock @( (New-Policy 'p-bad' 'Broken' 'groups' 100) ) @{ 'p-bad' = 'throw' }

        Test-MPAIGOV1015 | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'Error' }
    }

    It 'skips with NotAuthorized on a 403' {
        Mock Invoke-MtGraphRequest { throw [System.Exception]::new('403 Forbidden') }

        Test-MPAIGOV1015 | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'NotAuthorized' }
    }
}
