BeforeAll {
    . "$PSScriptRoot/../pack/helpers/ConvertTo-AIGovMarkdownCell.ps1"
    . "$PSScriptRoot/../pack/helpers/ConvertTo-AIGovMarkdownTable.ps1"
    . "$PSScriptRoot/../pack/tests/Test.MP.AIGOV.1043.ps1"

    $script:CopilotPolicy = @{
        Name = 'Copilot DLP'; Enabled = $true; Mode = 'Enable'; IsSimulationPolicy = $false
        Locations = @(@{ Workload = 'Applications'; Location = '470f2276-e011-4e9d-a6ec-20768be3a4b0' }); EnforcementPlanes = @('CopilotExperiences')
    }
    $script:Block = @(@{ setting = 'ExcludeContentProcessing'; value = 'Block' })
    $script:SitRule = @{ Name = 'Block SIT prompts'; ParentPolicyName = 'Copilot DLP'; Disabled = $false; RestrictAccess = $Block; ContentContainsSensitiveInformation = @(@{ name = 'Credit Card Number' }) }
    $script:LabelRule = @{ Name = 'Block labels'; ParentPolicyName = 'Copilot DLP'; Disabled = $false; RestrictAccess = $Block; AdvancedRule = '{"Condition":{"SubConditions":[{"ConditionName":"ContentContainsSensitiveInformation","Value":[{"groups":[{"labels":[{"name":"guid","type":"Sensitivity"}]}]}]}]}}' }
    $script:WebRule = @{ Name = 'No web for SIT'; ParentPolicyName = 'Copilot DLP'; Disabled = $false; RestrictWebGrounding = $true; ContentContainsSensitiveInformation = @(@{ name = 'U.S. Social Security Number (SSN)' }) }
    $script:ExternalRule = @{ Name = 'No external mail'; ParentPolicyName = 'Copilot DLP'; Disabled = $false; RestrictAccess = $Block; FromScope = 'NotInOrganization' }
}

Describe 'Test-MPAIGOV1043' {
    BeforeEach {
        Mock Add-MtTestResultDetail {}
    }

    It 'passes when all four protections are on' {
        Mock Get-MtExo { if ($Request -eq 'DlpCompliancePolicy') { @($CopilotPolicy) } else { @($SitRule, $LabelRule, $WebRule, $ExternalRule) } }
        Test-MPAIGOV1043 | Should -Be $true
    }

    It 'fails Medium when the labeled-content rule is missing' {
        Mock Get-MtExo { if ($Request -eq 'DlpCompliancePolicy') { @($CopilotPolicy) } else { @($SitRule, $WebRule) } }
        Test-MPAIGOV1043 | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Severity -eq 'Medium' -and $Result -match 'Block labeled files and email \| Missing' -and $Result -match 'Block prompts with sensitive info types \| On'
        }
    }

    It 'fails Low when only web search and external email protections are missing' {
        Mock Get-MtExo { if ($Request -eq 'DlpCompliancePolicy') { @($CopilotPolicy) } else { @($SitRule, $LabelRule) } }
        Test-MPAIGOV1043 | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Severity -eq 'Low' }
    }

    It 'ignores rules in a simulation policy and skips, leaving the finding to MT.1175' {
        $Sim = $CopilotPolicy.Clone(); $Sim.Mode = 'TestWithNotifications'
        Mock Get-MtExo { if ($Request -eq 'DlpCompliancePolicy') { @($Sim) } else { @($SitRule) } }
        Test-MPAIGOV1043 | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'Custom' -and $SkippedCustomReason -match 'MT.1175' }
    }

    It 'ignores a disabled rule' {
        $Off = $LabelRule.Clone(); $Off.Disabled = $true
        Mock Get-MtExo { if ($Request -eq 'DlpCompliancePolicy') { @($CopilotPolicy) } else { @($SitRule, $Off, $WebRule, $ExternalRule) } }
        Test-MPAIGOV1043 | Should -Be $false
    }
}
