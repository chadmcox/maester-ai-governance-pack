BeforeAll {
    . "$PSScriptRoot/Support/Set-AIGovGraphRoute.ps1"
    . "$PSScriptRoot/../pack/helpers/ConvertTo-AIGovMarkdownCell.ps1"
    . "$PSScriptRoot/../pack/helpers/ConvertTo-AIGovMarkdownTable.ps1"
    . "$PSScriptRoot/../pack/tests/Test.MP.AIGOV.1034.ps1"

    function New-RoleInstance([string]$Role, [string]$Id, [string]$Upn, [string]$Type = 'user', [string]$UserType = 'Member', [string]$AssignmentType = 'Activated', $End = '2026-12-01T00:00:00Z') {
        @{
            roleDefinitionId = $Role
            principalId      = $Id
            assignmentType   = $AssignmentType
            endDateTime      = $End
            principal        = @{ '@odata.type' = "#microsoft.graph.$Type"; userPrincipalName = $Upn; displayName = $Upn; userType = $UserType }
        }
    }
    $script:AiAdmin = 'd2562ede-74db-457e-a7b6-544e236ebb61'
}

Describe 'Test-MPAIGOV1034' {
    BeforeEach {
        Mock Add-MtTestResultDetail {}
    }

    It 'passes when every holder activated through PIM' {
        Set-AIGovGraphRoute @(
            , @('roleAssignmentScheduleInstances', @(New-RoleInstance $AiAdmin 'u1' 'a@contoso.com'), $AiAdmin)
            , @('roleAssignmentScheduleInstances', @())
        )
        Test-MPAIGOV1034 | Should -Be $true
    }

    It 'fails High on a permanent active assignment' {
        Set-AIGovGraphRoute @(
            , @('roleAssignmentScheduleInstances', @(New-RoleInstance $AiAdmin 'u1' 'a@contoso.com' -AssignmentType 'Assigned' -End $null), $AiAdmin)
            , @('roleAssignmentScheduleInstances', @())
        )
        Test-MPAIGOV1034 | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Severity -eq 'High' -and $Result -match 'permanent active assignment' }
    }

    It 'fails High on a guest holder and a service principal holder' {
        Set-AIGovGraphRoute @(
            , @('roleAssignmentScheduleInstances', @(
                    (New-RoleInstance $AiAdmin 'u1' 'guest#EXT#@contoso.com' -UserType 'Guest'),
                    (New-RoleInstance $AiAdmin 's1' 'Automation app' -Type 'servicePrincipal' -UserType $null)
                ), $AiAdmin)
            , @('roleAssignmentScheduleInstances', @())
        )
        Test-MPAIGOV1034 | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Result -match 'guest user' -and $Result -match 'non-human principal' }
    }

    It 'fails Medium when a role has more holders than allowed' {
        $Many = 1..4 | ForEach-Object { New-RoleInstance $AiAdmin "u$_" "user$_@contoso.com" }
        Set-AIGovGraphRoute @(
            , @('roleAssignmentScheduleInstances', $Many, $AiAdmin)
            , @('roleAssignmentScheduleInstances', @())
        )
        Test-MPAIGOV1034 -MaxHoldersPerRole 3 | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Severity -eq 'Medium' -and $Result -match 'AI Administrator \| 4' }
    }

    It 'falls back to roleAssignments and says permanence is unknown' {
        Set-AIGovGraphRoute @(
            , @('roleAssignmentScheduleInstances', 'throw:AadPremiumLicenseRequired')
            , @('roleAssignments', @(New-RoleInstance $AiAdmin 'u1' 'a@contoso.com' -AssignmentType $null -End $null), $AiAdmin)
            , @('roleAssignments', @())
        )
        Test-MPAIGOV1034 | Should -Be $true
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Result -match "can't tell permanent" }
    }

    It 'skips NotAuthorized on 403' {
        Set-AIGovGraphRoute @(, @('roleAssignmentScheduleInstances', 'throw:403 Forbidden'))
        Test-MPAIGOV1034 | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'NotAuthorized' }
    }
}
