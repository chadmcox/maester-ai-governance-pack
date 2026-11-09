# Dev-only Pester unit tests for Test-MPAIGOV1020. Not part of the installable pack.

BeforeAll {
    . "$PSScriptRoot/Support/Set-AIGovGraphRoute.ps1"
    . "$PSScriptRoot/../pack/helpers/Get-AIGovPackageCatalogSkipMessage.ps1"
    . "$PSScriptRoot/../pack/helpers/ConvertTo-AIGovMarkdownCell.ps1"
    . "$PSScriptRoot/../pack/helpers/ConvertTo-AIGovUtcDate.ps1"
    . "$PSScriptRoot/../pack/helpers/Get-AIGovPackageKind.ps1"
    . "$PSScriptRoot/../pack/helpers/Test-AIGovCustomPackage.ps1"
    . "$PSScriptRoot/../pack/tests/Test.MP.AIGOV.1020.ps1"

    function New-Package([string]$Id, [string]$Type = 'thirdParty', [string[]]$Elements = @('DeclarativeAgent'), [bool]$Blocked = $false) {
        [pscustomobject]@{ id = $Id; displayName = "Agent $Id name"; type = $Type; elementTypes = $Elements; isBlocked = $Blocked; lastModifiedDateTime = [datetime]::UtcNow.AddDays(-400).ToString('o') }
    }
    function New-Detail([int]$Active = 0, [object]$LastUsedDaysAgo = $null, [int]$ModifiedDaysAgo = 400) {
        [pscustomobject]@{
            activeUsers = $Active
            lastUsedDateTime = if ($null -ne $LastUsedDaysAgo) { [datetime]::UtcNow.AddDays(-[int]$LastUsedDaysAgo).ToString('o') } else { $null }
            lastModifiedDateTime = [datetime]::UtcNow.AddDays(-$ModifiedDaysAgo).ToString('o')
        }
    }
}

Describe 'Test-MPAIGOV1020' {
    BeforeEach { Mock Add-MtTestResultDetail { } }

    It 'flags a custom agent never used and not changed in 180 days' {
        Set-AIGovGraphRoute @(
            , @('^copilot/admin/catalog/packages$', @(New-Package 'p1'))
            , @('^copilot/admin/catalog/packages/p1$', (New-Detail))
        )
        Test-MPAIGOV1020 | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Severity -eq 'Medium' -and $Result -match 'p1' -and $Result -match 'Never' }
    }

    It 'passes for packages that are active, recently used or recently changed' {
        Set-AIGovGraphRoute @(
            , @('^copilot/admin/catalog/packages$', @((New-Package 'a'), (New-Package 'b'), (New-Package 'c')))
            , @('^copilot/admin/catalog/packages/a$', (New-Detail -Active 3))
            , @('^copilot/admin/catalog/packages/b$', (New-Detail -LastUsedDaysAgo 10))
            , @('^copilot/admin/catalog/packages/c$', (New-Detail -ModifiedDaysAgo 5))
        )
        Test-MPAIGOV1020 | Should -BeTrue
    }

    It 'ignores Microsoft, blocked and App-kind packages without reading their details' {
        Set-AIGovGraphRoute @(
            , @('^copilot/admin/catalog/packages$', @(
                    (New-Package 'ms' -Type 'firstParty'), (New-Package 'blk' -Blocked $true), (New-Package 'app' -Elements @('OfficeAddIns'))))
        )
        Test-MPAIGOV1020 | Should -BeTrue
        Should -Invoke Invoke-MtGraphRequest -Times 1 -Exactly
    }

    It 'honours StaleDays' {
        Set-AIGovGraphRoute @(
            , @('^copilot/admin/catalog/packages$', @(New-Package 'p1'))
            , @('^copilot/admin/catalog/packages/p1$', (New-Detail -LastUsedDaysAgo 100 -ModifiedDaysAgo 100))
        )
        Test-MPAIGOV1020 | Should -BeTrue
        Test-MPAIGOV1020 -StaleDays 90 | Should -BeFalse
    }

    It 'reports unreadable packages and skips when none can be read' {
        Set-AIGovGraphRoute @(
            , @('^copilot/admin/catalog/packages$', @((New-Package 'p1'), (New-Package 'p2')))
            , @('^copilot/admin/catalog/packages/p1$', (New-Detail))
            , @('^copilot/admin/catalog/packages/p2$', 'throw:Service unavailable')
        )
        Test-MPAIGOV1020 | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Result -match "1 package\(s\) couldn't be read" }

        Set-AIGovGraphRoute @(
            , @('^copilot/admin/catalog/packages$', @(New-Package 'p2'))
            , @('^copilot/admin/catalog/packages/p2$', 'throw:Service unavailable')
        )
        Test-MPAIGOV1020 | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -ParameterFilter { $SkippedBecause -eq 'Error' }
    }

    It 'skips with NotAuthorized on a 403' {
        Mock Invoke-MtGraphRequest { throw [System.Exception]::new('403 Forbidden') }
        Test-MPAIGOV1020 | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'NotAuthorized' }
    }
}
