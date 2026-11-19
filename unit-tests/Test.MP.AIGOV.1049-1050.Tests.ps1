BeforeAll {
    . "$PSScriptRoot/../pack/tests/Test.MP.AIGOV.1049.ps1"
    . "$PSScriptRoot/../pack/tests/Test.MP.AIGOV.1050.ps1"
}

Describe 'Test-MPAIGOV1049' {
    BeforeEach { Mock Add-MtTestResultDetail {} }

    It 'passes when agents are restricted from external sharing' {
        Mock Get-MtSpo { [pscustomobject]@{ SharingCapability = 'ExternalUserAndGuestSharing'; RestrictExternalSharingForAgents = $true } }
        Test-MPAIGOV1049 | Should -Be $true
    }

    It 'passes when external sharing is off for the tenant' {
        Mock Get-MtSpo { [pscustomobject]@{ SharingCapability = 'Disabled'; RestrictExternalSharingForAgents = $false } }
        Test-MPAIGOV1049 | Should -Be $true
    }

    It 'fails Medium when agents can share externally' {
        Mock Get-MtSpo { [pscustomobject]@{ SharingCapability = 'ExternalUserSharingOnly'; RestrictExternalSharingForAgents = $false } }
        Test-MPAIGOV1049 | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Severity -eq 'Medium' -and $Result -match 'ExternalUserSharingOnly' }
    }

    It 'skips when the setting is not returned and sharing is on' {
        Mock Get-MtSpo { [pscustomobject]@{ SharingCapability = 'ExternalUserSharingOnly' } }
        Test-MPAIGOV1049 | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'Custom' -and $SkippedCustomReason -match 'preview' }
    }

    It 'passes without the setting when sharing is off' {
        Mock Get-MtSpo { [pscustomobject]@{ SharingCapability = 'Disabled' } }
        Test-MPAIGOV1049 | Should -Be $true
    }

    It 'skips when SharePoint cannot be read' {
        Mock Get-MtSpo { throw 'not connected' }
        Test-MPAIGOV1049 | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'Custom' }
    }
}

Describe 'Test-MPAIGOV1050' {
    BeforeEach { Mock Add-MtTestResultDetail {} }

    It 'passes when neither control is delegated' {
        Mock Get-MtSpo { [pscustomobject]@{ DelegateRestrictedContentDiscoverabilityManagement = $false; DelegateRestrictedAccessControlManagement = $false } }
        Test-MPAIGOV1050 | Should -Be $true
    }

    It 'fails Low when content discovery is delegated' {
        Mock Get-MtSpo { [pscustomobject]@{ DelegateRestrictedContentDiscoverabilityManagement = $true; DelegateRestrictedAccessControlManagement = $false } }
        Test-MPAIGOV1050 | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Severity -eq 'Low' -and $Result -match 'change 1 restriction' -and $Result -match 'DelegateRestrictedContentDiscoverabilityManagement \| True \| Fail'
        }
    }

    It 'reads the PnP names (...Configuration)' {
        Mock Get-MtSpo { [pscustomobject]@{ DelegateRestrictedContentDiscoveryConfiguration = $false; DelegateRestrictedAccessControlConfiguration = $true } }
        Test-MPAIGOV1050 | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Result -match 'DelegateRestrictedAccessControlConfiguration \| True \| Fail' -and $Result -match 'DelegateRestrictedContentDiscoveryConfiguration \| False \| Pass'
        }
    }

    It 'checks the setting that is returned and lists the other as not returned' {
        Mock Get-MtSpo { [pscustomobject]@{ DelegateRestrictedAccessControlManagement = $false } }
        Test-MPAIGOV1050 | Should -Be $true
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Result -match 'Not returned' }
    }

    It 'skips when neither setting is returned' {
        Mock Get-MtSpo { [pscustomobject]@{ SharingCapability = 'Disabled' } }
        Test-MPAIGOV1050 | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'Custom' }
    }
}
