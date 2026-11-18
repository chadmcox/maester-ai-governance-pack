BeforeAll {
    # Security & Compliance PowerShell isn't loaded in unit tests; give Pester a command to mock.
    function Get-UnifiedAuditLogRetentionPolicy { param([Parameter(ValueFromRemainingArguments)]$Rest) }
    . "$PSScriptRoot/../pack/tests/Test.MP.AIGOV.1044.ps1"
}

Describe 'Test-MPAIGOV1044' {
    BeforeEach {
        Mock Add-MtTestResultDetail {}
    }

    It 'passes when a policy keeps CopilotInteraction for twelve months' {
        Mock Get-UnifiedAuditLogRetentionPolicy { @(@{ Name = 'AI audit'; RecordTypes = @('CopilotInteraction'); RetentionDuration = 'TwelveMonths' }) }
        Test-MPAIGOV1044 | Should -Be $true
    }

    It 'fails Medium when retention is shorter than the minimum' {
        Mock Get-UnifiedAuditLogRetentionPolicy { @(@{ Name = 'AI audit'; RecordTypes = @('CopilotInteraction'); RetentionDuration = 'SixMonths' }) }
        Test-MPAIGOV1044 | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Severity -eq 'Medium' -and $Result -match 'SixMonths, less than' }
    }

    It 'ignores a policy narrowed to some users and fails' {
        Mock Get-UnifiedAuditLogRetentionPolicy { @(@{ Name = 'VIP'; RecordTypes = @('CopilotInteraction'); UserIds = @('ceo@contoso.com'); RetentionDuration = 'TenYears' }) }
        Test-MPAIGOV1044 | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Result -match '180 days' }
    }

    It 'honors a higher minimum' {
        Mock Get-UnifiedAuditLogRetentionPolicy { @(@{ Name = 'AI audit'; RecordTypes = @('CopilotInteraction', 'ConnectedAIAppInteraction'); RetentionDuration = 'TwelveMonths' }) }
        Test-MPAIGOV1044 -MinimumRetention TenYears | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Result -match 'ConnectedAIAppInteraction records are kept' }
    }

    It 'skips when the cmdlet is not available' {
        Mock Get-UnifiedAuditLogRetentionPolicy { throw [System.Management.Automation.CommandNotFoundException]::new('Get-UnifiedAuditLogRetentionPolicy is not recognized') }
        Test-MPAIGOV1044 | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'NotConnectedSecurityCompliance' }
    }
}
