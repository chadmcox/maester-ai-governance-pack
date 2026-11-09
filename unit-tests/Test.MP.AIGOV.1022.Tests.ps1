# Dev-only Pester unit tests for Test-MPAIGOV1022. Not part of the installable pack.

BeforeAll {
    . "$PSScriptRoot/Support/Set-AIGovGraphRoute.ps1"
    . "$PSScriptRoot/../pack/helpers/ConvertTo-AIGovMarkdownCell.ps1"
    . "$PSScriptRoot/../pack/tests/Test.MP.AIGOV.1022.ps1"

    $script:GraphSp = [pscustomobject]@{
        id = 'graph-sp'
        appRoles = @(
            [pscustomobject]@{ id = 'r-dir'; value = 'Directory.ReadWrite.All' },
            [pscustomobject]@{ id = 'r-mail'; value = 'Mail.Send' },
            [pscustomobject]@{ id = 'r-tasks'; value = 'Tasks.ReadWrite.All' },
            [pscustomobject]@{ id = 'r-read'; value = 'User.Read.All' },
            [pscustomobject]@{ id = 'r-ca'; value = 'Policy.ReadWrite.ConditionalAccess' }
        )
    }

    function Get-Routes([object[]]$AgentAssignments = @(), [object[]]$AgentGrants = @(), [object[]]$BlueprintAssignments = @()) {
        @(
            , @('^servicePrincipals/microsoft\.graph\.agentIdentity$', @([pscustomobject]@{ id = 'a1'; displayName = 'Expense Agent'; appId = 'app-a1' }))
            , @('^servicePrincipals/microsoft\.graph\.agentIdentityBlueprintPrincipal$', @([pscustomobject]@{ id = 'b1'; displayName = 'Expense Blueprint'; appId = 'app-b1' }))
            , @('^servicePrincipals$', @($script:GraphSp), "00000003-0000-0000-c000-000000000000")
            , @('^servicePrincipals/a1/appRoleAssignments$', $AgentAssignments)
            , @('^servicePrincipals/a1/oauth2PermissionGrants$', $AgentGrants)
            , @('^servicePrincipals/b1/appRoleAssignments$', $BlueprintAssignments)
            , @('^servicePrincipals/b1/oauth2PermissionGrants$', @())
            , @('inheritedAppRoleAssignments$', @())
            , @('inheritedOauth2PermissionGrants$', @())
        )
    }
    function New-Assignment([string]$RoleId, [string]$Resource = 'graph-sp') { [pscustomobject]@{ appRoleId = $RoleId; resourceId = $Resource } }
}

Describe 'Test-MPAIGOV1022' {
    BeforeEach { Mock Add-MtTestResultDetail { } }

    It 'passes with read-only permissions' {
        Set-AIGovGraphRoute (Get-Routes -AgentAssignments @(New-Assignment 'r-read'))
        Test-MPAIGOV1022 | Should -BeTrue
    }

    It 'flags High for high-privilege application and admin-consented delegated permissions' {
        Set-AIGovGraphRoute (Get-Routes `
            -AgentAssignments @(New-Assignment 'r-dir') `
            -AgentGrants @([pscustomobject]@{ resourceId = 'graph-sp'; scope = 'Mail.Send openid'; consentType = 'AllPrincipals' }))
        Test-MPAIGOV1022 | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Severity -eq 'High' -and $Result -match 'Directory.ReadWrite.All \(Application\)' -and $Result -match 'Mail.Send \(Delegated\)'
        }
    }

    It 'flags Medium for other tenant-wide write permissions, including on blueprint principals' {
        Set-AIGovGraphRoute (Get-Routes -BlueprintAssignments @(New-Assignment 'r-tasks'))
        Test-MPAIGOV1022 | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Severity -eq 'Medium' -and $Result -match 'Blueprint principal' -and $Result -match 'Tasks.ReadWrite.All' }
    }

    It 'leaves MT.1223 permissions, user-consented grants and non-Graph resources alone' {
        Set-AIGovGraphRoute (Get-Routes `
            -AgentAssignments @((New-Assignment 'r-ca'), (New-Assignment 'r-dir' -Resource 'other-api')) `
            -AgentGrants @([pscustomobject]@{ resourceId = 'graph-sp'; scope = 'Mail.Send'; consentType = 'Principal' }))
        Test-MPAIGOV1022 | Should -BeTrue
    }

    It 'skips with NotAuthorized on a 403' {
        Mock Invoke-MtGraphRequest { throw [System.Exception]::new('403 Forbidden') }
        Test-MPAIGOV1022 | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'NotAuthorized' }
    }

    It 'keeps its MT.1223 list identical to MP.AIGOV.1019' {
        $Read = {
            param($Path)
            $Raw = Get-Content -Path (Join-Path $PSScriptRoot $Path) -Raw
            if ($Raw -notmatch '(?s)\$HighRiskScopes\s*=\s*@\(([^)]*)\)') { throw "No `$HighRiskScopes in $Path" }
            @([regex]::Matches($Matches[1], "'([^']+)'") | ForEach-Object { $_.Groups[1].Value } | Sort-Object)
        }
        $List1019 = & $Read '../pack/tests/Test.MP.AIGOV.1019.ps1'
        $List1022 = & $Read '../pack/tests/Test.MP.AIGOV.1022.ps1'
        $List1019.Count | Should -BeGreaterThan 0
        ($List1022 -join '|') | Should -Be ($List1019 -join '|')
    }
}
