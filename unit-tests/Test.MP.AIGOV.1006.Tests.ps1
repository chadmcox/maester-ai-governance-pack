# Dev-only Pester unit tests for Test-MPAIGOV1006 (pack/tests/Test.MP.AIGOV.1006.ps1).
#
# This folder is NOT part of the installable pack. Test-MtPack and Install-MtPack both run a
# repo-wide content-safety scan that rejects any .ps1 file whose top level is not exclusively
# function definitions -- a Pester *.Tests.ps1 file (top-level Describe/BeforeAll) fails that scan.
# Keeping unit tests at the repo root, outside pack/, means:
#   - `Install-MtPack chadmcox/maester-ai-governance-pack/pack` never sees this folder.
#   - `Test-MtPack ./pack` only scans the installable pack content.
#   - `Invoke-Pester ./unit-tests` still runs these tests in CI and locally.
#
# This file is a minimal proof of the dot-source + Mock pattern against the new pack/ layout.
# The full PR A (.1016-.1019) unit-test suite lands here when that branch rebases onto this one.

BeforeAll {
    $MaesterModulePath = $env:MAESTER_MODULE_PATH
    if (-not $MaesterModulePath) {
        throw 'MAESTER_MODULE_PATH must point at a local Maester.psd1 (needed for the [MaesterTest()] attribute type).'
    }
    Import-Module $MaesterModulePath -Force

    . "$PSScriptRoot/../pack/helpers/Get-AIGovPackageCatalogSkipMessage.ps1"
    . "$PSScriptRoot/../pack/tests/Test.MP.AIGOV.1006.ps1"
}

Describe 'Test-MPAIGOV1006' {
    BeforeEach {
        Mock Add-MtTestResultDetail { } -Verifiable
    }

    It 'passes when every package has a clear name and description' {
        Mock Invoke-MtGraphRequest {
            @(
                [pscustomobject]@{ id = 'pkg-1'; displayName = 'Contoso Assistant'; shortDescription = 'Helps with expense reports.'; longDescription = '' }
            )
        }

        $Result = Test-MPAIGOV1006

        $Result | Should -BeTrue
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Result -match 'Well done' }
    }

    It 'flags a placeholder display name and an empty description' {
        Mock Invoke-MtGraphRequest {
            @(
                [pscustomobject]@{ id = 'pkg-2'; displayName = 'Test Agent'; shortDescription = ''; longDescription = '' },
                [pscustomobject]@{ id = 'pkg-3'; displayName = ''; shortDescription = 'Has a description.'; longDescription = '' }
            )
        }

        $Result = Test-MPAIGOV1006

        $Result | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Result -match 'pkg-2' -and $Result -match 'pkg-3' -and $Severity -eq 'Info'
        }
    }

    It 'skips with NotAuthorized on a 403' {
        Mock Invoke-MtGraphRequest { throw [System.Exception]::new('403 Forbidden') }

        $Result = Test-MPAIGOV1006

        $Result | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'NotAuthorized' }
    }

    It 'skips with Error on an unrelated failure' {
        Mock Invoke-MtGraphRequest { throw [System.Exception]::new('Service unavailable') }

        $Result = Test-MPAIGOV1006

        $Result | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'Error' }
    }
}
