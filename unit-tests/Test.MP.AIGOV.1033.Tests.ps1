# Dev-only Pester unit tests for Test-MPAIGOV1033. Not part of the installable pack.

BeforeAll {
    . "$PSScriptRoot/Support/Set-AIGovGraphRoute.ps1"
    . "$PSScriptRoot/../pack/helpers/ConvertTo-AIGovMarkdownCell.ps1"
    . "$PSScriptRoot/../pack/tests/Test.MP.AIGOV.1033.ps1"

    $script:TenantId = '11111111-1111-1111-1111-111111111111'
    function New-Connection([string]$Id, [string]$State = 'ready', [string]$Description = 'Service desk tickets', [string[]]$AppIds = @()) {
        [pscustomobject]@{
            id = $Id; name = "Conn $Id"; description = $Description; state = $State
            configuration = [pscustomobject]@{ authorizedAppIds = $AppIds }
        }
    }
}

Describe 'Test-MPAIGOV1033' {
    BeforeEach { Mock Add-MtTestResultDetail { } }

    It 'passes and lists the inventory when every searchable connection is clean' {
        Set-AIGovGraphRoute @(
            , @('^external/connections$', @((New-Connection 'c1' -AppIds @('own-app')), (New-Connection 'c2' -State 'draft' -Description '')))
            , @('^organization$', @([pscustomobject]@{ id = $script:TenantId }))
            , @('^servicePrincipals$', @([pscustomobject]@{ id = 'sp1'; displayName = 'Our indexer'; appOwnerOrganizationId = $script:TenantId }), "own-app")
        )
        Test-MPAIGOV1033 | Should -BeTrue
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Result -match 'Well done' -and $Result -match 'Conn c1' -and $Result -notmatch 'Conn c2' -and $Result -match '1 draft or obsolete'
        }
    }

    It 'passes when no connection is searchable' {
        Set-AIGovGraphRoute @( , @('^external/connections$', @((New-Connection 'c1' -State 'obsolete'))) )
        Test-MPAIGOV1033 | Should -BeTrue
    }

    It 'flags a missing app and an outside app as Medium, and limitExceeded and no description as Low' {
        Set-AIGovGraphRoute @(
            , @('^external/connections$', @(
                    (New-Connection 'c1' -AppIds @('gone-app', 'vendor-app', 'ms-app')),
                    (New-Connection 'c2' -State 'limitExceeded' -Description '')
                ))
            , @('^organization$', @([pscustomobject]@{ id = $script:TenantId }))
            , @('^servicePrincipals$', @(), "gone-app")
            , @('^servicePrincipals$', @([pscustomobject]@{ id = 'sp2'; displayName = 'Vendor Indexer'; appOwnerOrganizationId = '22222222-2222-2222-2222-222222222222' }), "vendor-app")
            , @('^servicePrincipals$', @([pscustomobject]@{ id = 'sp3'; displayName = 'Microsoft Search'; appOwnerOrganizationId = 'f8cdef31-a31e-4b4a-93e4-5f571e91255a' }), "ms-app")
        )
        Test-MPAIGOV1033 | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Severity -eq 'Medium' -and
            $Result -match 'gone-app has no service principal' -and
            $Result -match 'Vendor Indexer' -and
            $Result -notmatch 'Microsoft Search' -and
            $Result -match 'Index limit exceeded' -and
            $Result -match 'No description'
        }
    }

    It 'skips the outside-app rule, and says so, when the tenant ID cannot be read' {
        Set-AIGovGraphRoute @(
            , @('^external/connections$', @((New-Connection 'c1' -AppIds @('vendor-app'))))
            , @('^organization$', 'throw:boom')
            , @('^servicePrincipals$', @([pscustomobject]@{ id = 'sp2'; displayName = 'Vendor Indexer'; appOwnerOrganizationId = '22222222-2222-2222-2222-222222222222' }))
        )
        Test-MPAIGOV1033 | Should -BeTrue
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Result -match "outside-owned apps weren't checked" }
    }

    It 'skips as NotAuthorized on a 403' {
        Set-AIGovGraphRoute @( , @('^external/connections$', 'throw:403 Forbidden') )
        Test-MPAIGOV1033 | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'NotAuthorized' }
    }
}
