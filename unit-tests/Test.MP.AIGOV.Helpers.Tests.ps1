# Dev-only Pester unit tests for the pack's shared helpers. Not part of the installable pack.

BeforeAll {
    . "$PSScriptRoot/../pack/helpers/Test-AIGovUnclearName.ps1"
    . "$PSScriptRoot/../pack/helpers/Test-AIGovPoorDescription.ps1"
    . "$PSScriptRoot/../pack/helpers/Get-AIGovPackageKind.ps1"
    . "$PSScriptRoot/../pack/helpers/Test-AIGovCustomPackage.ps1"
    . "$PSScriptRoot/../pack/helpers/ConvertTo-AIGovUtcDate.ps1"
    . "$PSScriptRoot/../pack/helpers/Test-AIGovNotFoundError.ps1"
    . "$PSScriptRoot/../pack/helpers/Test-AIGovPackageUserAccessible.ps1"
}

Describe 'Test-AIGovUnclearName' {
    It 'flags <Name>' -ForEach @(
        @{ Name = '' }, @{ Name = 'HR' }, @{ Name = 'Test agent' }, @{ Name = 'Demo bot' }, @{ Name = 'Sales POC' },
        @{ Name = 'New agent' }, @{ Name = 'My bot for stuff' }, @{ Name = 'Expense Agent 2' }, @{ Name = 'Expense helper (1)' },
        @{ Name = 'Do not use - old' }, @{ Name = 'Sandbox finance' }, @{ Name = 'Test (Microsoft Copilot Studio)' }
    ) {
        Test-AIGovUnclearName -Name $Name | Should -BeTrue
    }

    It 'accepts <Name>' -ForEach @(
        @{ Name = 'Contoso Expense Assistant' }, @{ Name = 'Contest Entry Helper' }, @{ Name = 'HR Policy Agent (Microsoft Copilot Studio)' }
    ) {
        Test-AIGovUnclearName -Name $Name | Should -BeFalse
    }
}

Describe 'Test-AIGovPoorDescription' {
    It 'flags empty, short and name-only descriptions' {
        Test-AIGovPoorDescription -Description '' -Name 'X' | Should -BeTrue
        Test-AIGovPoorDescription -Description 'Does things' -Name 'X' | Should -BeTrue
        Test-AIGovPoorDescription -Description 'Contoso Expense Assistant' -Name 'Contoso Expense Assistant' | Should -BeTrue
    }
    It 'accepts a real description' {
        Test-AIGovPoorDescription -Description 'Answers expense policy questions for Finance.' -Name 'Expense Agent' | Should -BeFalse
    }
}

Describe 'Get-AIGovPackageKind' {
    It 'classifies <Types> as <Kind>' -ForEach @(
        @{ Types = @('DeclarativeAgent'); Kind = 'Agent' }, @{ Types = @('Bots', 'Tabs'); Kind = 'Agent' },
        @{ Types = @('MCPServers'); Kind = 'Tool' }, @{ Types = @('AgentSkills'); Kind = 'Tool' }, @{ Types = @('AgentConnectors'); Kind = 'Tool' },
        @{ Types = @('OfficeAddIns'); Kind = 'App' }, @{ Types = @(); Kind = 'App' }
    ) {
        Get-AIGovPackageKind -ElementTypes $Types | Should -Be $Kind
    }
}

Describe 'Test-AIGovCustomPackage' {
    It 'treats firstParty as Microsoft and anything else as custom' {
        Test-AIGovCustomPackage -Package ([pscustomobject]@{ type = 'firstParty' }) | Should -BeFalse
        Test-AIGovCustomPackage -Package ([pscustomobject]@{ type = 'thirdParty' }) | Should -BeTrue
        Test-AIGovCustomPackage -Package ([pscustomobject]@{ type = 'lineOfBusiness' }) | Should -BeTrue
    }
    It 'falls back to the publisher when type is missing' {
        Test-AIGovCustomPackage -Package ([pscustomobject]@{ publisher = 'Microsoft Corporation' }) | Should -BeFalse
        Test-AIGovCustomPackage -Package ([pscustomobject]@{ publisher = 'Contoso' }) | Should -BeTrue
    }
}

Describe 'ConvertTo-AIGovUtcDate' {
    It 'handles strings, datetimes and empty values' {
        (ConvertTo-AIGovUtcDate -Value '2026-01-02T03:04:05Z').ToString('yyyy-MM-ddTHH:mm:ss') | Should -Be '2026-01-02T03:04:05'
        (ConvertTo-AIGovUtcDate -Value ([datetime]::new(2026, 1, 2, 3, 4, 5, [System.DateTimeKind]::Utc))).Day | Should -Be 2
        ConvertTo-AIGovUtcDate -Value $null | Should -BeNullOrEmpty
        ConvertTo-AIGovUtcDate -Value '' | Should -BeNullOrEmpty
        ConvertTo-AIGovUtcDate -Value 'not a date' | Should -BeNullOrEmpty
    }
}

Describe 'Test-AIGovNotFoundError' {
    It 'tells a 404 apart from other failures' {
        Test-AIGovNotFoundError -ErrorRecord ([System.Management.Automation.ErrorRecord]::new([System.Exception]::new('Response status code does not indicate success: 404 (Not Found).'), 'x', 'NotSpecified', $null)) | Should -BeTrue
        Test-AIGovNotFoundError -ErrorRecord ([System.Management.Automation.ErrorRecord]::new([System.Exception]::new('403 Forbidden'), 'x', 'NotSpecified', $null)) | Should -BeFalse
        Test-AIGovNotFoundError -ErrorRecord ([System.Management.Automation.ErrorRecord]::new([System.Exception]::new('Service unavailable'), 'x', 'NotSpecified', $null)) | Should -BeFalse
    }
}

Describe 'Test-AIGovPackageUserAccessible' {
    It 'treats <Label> as out of reach' -ForEach @(
        @{ Label = 'a blocked package'; Package = [pscustomobject]@{ isBlocked = $true; availableTo = 'allowedForAll' } },
        @{ Label = 'a blocked package (string flag)'; Package = [pscustomobject]@{ isBlocked = 'true'; availableTo = 'allowedForSome' } },
        @{ Label = 'a package allowed for no one'; Package = [pscustomobject]@{ isBlocked = $false; availableTo = 'allowedForNone' } },
        @{ Label = 'a null package'; Package = $null }
    ) {
        Test-AIGovPackageUserAccessible -Package $Package | Should -BeFalse
    }

    It 'treats <Label> as reachable' -ForEach @(
        @{ Label = 'allowed for all'; Package = [pscustomobject]@{ isBlocked = $false; availableTo = 'allowedForAll' } },
        @{ Label = 'allowed for some'; Package = [pscustomobject]@{ isBlocked = $false; availableTo = 'allowedForSome' } },
        @{ Label = 'missing isBlocked and availableTo'; Package = [pscustomobject]@{ id = 'p1' } }
    ) {
        Test-AIGovPackageUserAccessible -Package $Package | Should -BeTrue
    }
}
