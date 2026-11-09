# Dev-only Pester unit tests for Test-MPAIGOV1024. Not part of the installable pack.

BeforeAll {
    . "$PSScriptRoot/Support/Set-AIGovGraphRoute.ps1"
    . "$PSScriptRoot/../pack/helpers/ConvertTo-AIGovMarkdownCell.ps1"
    . "$PSScriptRoot/../pack/helpers/ConvertTo-AIGovUtcDate.ps1"
    . "$PSScriptRoot/../pack/helpers/Get-AIGovClassicCopilotServicePrincipal.ps1"
    . "$PSScriptRoot/../pack/tests/Test.MP.AIGOV.1024.ps1"

    function New-Sp([string]$Id, [bool]$Enabled = $true, [int]$CreatedDaysAgo = 400) {
        [pscustomobject]@{ id = $Id; appId = "app-$Id"; displayName = "Classic $Id"; accountEnabled = $Enabled; createdDateTime = [datetime]::UtcNow.AddDays(-$CreatedDaysAgo).ToString('o') }
    }
    function New-Activity([string]$AppId, [object]$DaysAgo) {
        $Last = if ($null -ne $DaysAgo) { [datetime]::UtcNow.AddDays(-[int]$DaysAgo).ToString('o') } else { $null }
        [pscustomobject]@{ appId = $AppId; lastSignInActivity = [pscustomobject]@{ lastSignInDateTime = $Last } }
    }
    function Get-Routes([object[]]$Sps, [hashtable]$Owners, [hashtable]$Activity) {
        $Routes = [System.Collections.Generic.List[object]]::new()
        $Routes.Add(@('agentIdentity$', @()))
        $Routes.Add(@('agentIdentityBlueprintPrincipal$', @()))
        $Routes.Add(@('^servicePrincipals$', $Sps, 'AgentCreatedBy:CopilotStudio'))
        $Routes.Add(@('^servicePrincipals$', @(), '.'))
        foreach ($Key in $Owners.Keys) { $Routes.Add(@("^servicePrincipals/$Key/owners$", $Owners[$Key])) }
        foreach ($Key in $Activity.Keys) { $Routes.Add(@('^reports/servicePrincipalSignInActivities$', $Activity[$Key], "app-$Key")) }
        , $Routes.ToArray()
    }
}

Describe 'Test-MPAIGOV1024' {
    BeforeEach { Mock Add-MtTestResultDetail { } }

    It 'passes when there are no classic service principals' {
        Set-AIGovGraphRoute (Get-Routes @() @{} @{})
        Test-MPAIGOV1024 | Should -BeTrue
    }

    It 'flags no owner (Medium), stale (Low) and never signed in (Low)' {
        Set-AIGovGraphRoute (Get-Routes @((New-Sp 's1'), (New-Sp 's2'), (New-Sp 's3'), (New-Sp 'ok')) `
            @{ s1 = @(); s2 = @([pscustomobject]@{ id = 'o' }); s3 = @([pscustomobject]@{ id = 'o' }); ok = @([pscustomobject]@{ id = 'o' }) } `
            @{ s1 = @(New-Activity 'app-s1' 5); s2 = @(New-Activity 'app-s2' 300); s3 = @(New-Activity 'app-s3' $null); ok = @(New-Activity 'app-ok' 1) })
        Test-MPAIGOV1024 | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Severity -eq 'Medium' -and $Result -match 'Found 3 of 4' -and $Result -match 'Classic s1.*No owner' -and
            $Result -match 'Classic s2.*No sign-in for 180 days' -and $Result -match 'Classic s3.*No sign-in recorded' -and $Result -notmatch 'Classic ok'
        }
    }

    It 'does not check sign-ins for disabled or recently created service principals' {
        Set-AIGovGraphRoute (Get-Routes @((New-Sp 'off' -Enabled $false), (New-Sp 'new' -CreatedDaysAgo 10)) `
            @{ off = @([pscustomobject]@{ id = 'o' }); new = @([pscustomobject]@{ id = 'o' }) } @{})
        Test-MPAIGOV1024 | Should -BeTrue
    }

    It 'skips only the sign-in check when the report is forbidden' {
        $Routes = Get-Routes @(New-Sp 's1') @{ s1 = @([pscustomobject]@{ id = 'o' }) } @{}
        $Routes += , @('^reports/servicePrincipalSignInActivities$', 'throw:403 Forbidden')
        Set-AIGovGraphRoute $Routes
        Test-MPAIGOV1024 | Should -BeTrue
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Result -match 'sign-in check was skipped' }
    }

    It 'skips with NotAuthorized on a 403' {
        Mock Invoke-MtGraphRequest { throw [System.Exception]::new('403 Forbidden') }
        Test-MPAIGOV1024 | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'NotAuthorized' }
    }
}
