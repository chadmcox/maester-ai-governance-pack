# Dev-only Pester unit tests for Test-MPAIGOV1021. Not part of the installable pack.

BeforeAll {
    . "$PSScriptRoot/Support/Set-AIGovGraphRoute.ps1"
    . "$PSScriptRoot/../pack/helpers/Get-AIGovPackageCatalogSkipMessage.ps1"
    . "$PSScriptRoot/../pack/helpers/ConvertTo-AIGovMarkdownCell.ps1"
    . "$PSScriptRoot/../pack/helpers/Get-AIGovPackageKind.ps1"
    . "$PSScriptRoot/../pack/helpers/Test-AIGovNotFoundError.ps1"
    . "$PSScriptRoot/../pack/tests/Test.MP.AIGOV.1021.ps1"

    $script:Catalog = @(
        [pscustomobject]@{ id = 'p1'; displayName = 'Expense Agent'; elementTypes = @('DeclarativeAgent') },
        [pscustomobject]@{ id = 'p2'; displayName = 'Word add-in'; elementTypes = @('OfficeAddIns') }
    )
    function New-Audience([string[]]$GroupIds) {
        [pscustomobject]@{
            id = 'p1'
            allowedUsersAndGroups = @($GroupIds | ForEach-Object { [pscustomobject]@{ resourceType = 'group'; resourceId = $_ } }) + @([pscustomobject]@{ resourceType = 'user'; resourceId = 'u1' })
            acquireUsersAndGroups = @()
        }
    }
}

Describe 'Test-MPAIGOV1021' {
    BeforeEach { Mock Add-MtTestResultDetail { } }

    It 'passes when the group exists, has two owners and a description' {
        Set-AIGovGraphRoute @(
            , @('^copilot/admin/catalog/packages$', $script:Catalog)
            , @('^copilot/admin/catalog/packages/p1$', (New-Audience @('g1')))
            , @('^groups/g1/owners$', @([pscustomobject]@{ id = 'o1' }, [pscustomobject]@{ id = 'o2' }))
            , @('^groups/g1$', [pscustomobject]@{ id = 'g1'; displayName = 'Finance'; description = 'Finance team: Expense Agent users' })
        )
        Test-MPAIGOV1021 | Should -BeTrue
    }

    It 'flags a deleted group, too few owners and no description' {
        Set-AIGovGraphRoute @(
            , @('^copilot/admin/catalog/packages$', $script:Catalog)
            , @('^copilot/admin/catalog/packages/p1$', (New-Audience @('g1', 'gone')))
            , @('^groups/gone', 'throw:Request_ResourceNotFound: 404')
            , @('^groups/g1/owners$', @([pscustomobject]@{ id = 'o1' }))
            , @('^groups/g1$', [pscustomobject]@{ id = 'g1'; displayName = 'Finance'; description = '' })
        )
        Test-MPAIGOV1021 | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Severity -eq 'Medium' -and $Result -match 'gone.*Group no longer exists' -and $Result -match 'Has 1 owner' -and $Result -match 'No description'
        }
    }

    It 'does not read App-kind packages' {
        Set-AIGovGraphRoute @(
            , @('^copilot/admin/catalog/packages$', @($script:Catalog[1]))
        )
        Test-MPAIGOV1021 | Should -BeTrue
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Result -match 'No agent or tool is assigned to a group' }
    }

    It 'skips with Error when no package detail can be read' {
        Set-AIGovGraphRoute @(
            , @('^copilot/admin/catalog/packages$', $script:Catalog)
            , @('^copilot/admin/catalog/packages/p1$', 'throw:Service unavailable')
        )
        Test-MPAIGOV1021 | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'Error' }
    }

    It 'skips with NotAuthorized on a 403' {
        Mock Invoke-MtGraphRequest { throw [System.Exception]::new('403 Forbidden') }
        Test-MPAIGOV1021 | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'NotAuthorized' }
    }
}
