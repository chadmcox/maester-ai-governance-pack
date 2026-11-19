BeforeAll {
    . "$PSScriptRoot/../pack/helpers/ConvertTo-AIGovMarkdownCell.ps1"
    . "$PSScriptRoot/../pack/helpers/ConvertTo-AIGovMarkdownTable.ps1"
    . "$PSScriptRoot/../pack/helpers/Get-AIGovAzureAiAccount.ps1"
    . "$PSScriptRoot/../pack/helpers/Get-AIGovAzureAiDeployment.ps1"
    . "$PSScriptRoot/../pack/helpers/Invoke-AIGovAzureList.ps1"
    . "$PSScriptRoot/../pack/tests/Test.MP.AIGOV.1046.ps1"
    . "$PSScriptRoot/../pack/tests/Test.MP.AIGOV.1047.ps1"
    . "$PSScriptRoot/../pack/tests/Test.MP.AIGOV.1048.ps1"

    # Mocks Invoke-MtAzureRequest from a hashtable of '<regex on RelativeUri>' = <value>.
    # A value of 'throw' throws; $null means 401/403 (Invoke-MtAzureRequest returns $null).
    function Set-AzureRoute([hashtable]$Routes) {
        $script:AzureRoutes = $Routes
        Mock Invoke-MtAzureRequest {
            foreach ($Key in $script:AzureRoutes.Keys) {
                if ($RelativeUri -match $Key) {
                    $Value = $script:AzureRoutes[$Key]
                    if ($Value -eq 'throw') { throw 'boom' }
                    return $Value
                }
            }
            throw "Unexpected RelativeUri in test: $RelativeUri"
        }
    }

    function New-Account([string]$Name, [string]$Sub = 's1') {
        @{ id = "/subscriptions/$Sub/resourceGroups/rg/providers/Microsoft.CognitiveServices/accounts/$Name"; name = $Name; subscriptionId = $Sub; resourceGroup = 'rg'; kind = 'OpenAI' }
    }
    function New-Deployment([string]$Name, [string]$Model, [string]$Version = '1', [string]$Rai) {
        @{ name = $Name; properties = @{ model = @{ name = $Model; version = $Version; format = 'OpenAI' }; raiPolicyName = $Rai } }
    }
    function New-Filter([string]$Name, [bool]$Enabled = $true, [bool]$Blocking = $true) {
        @{ name = $Name; enabled = $Enabled; blocking = $Blocking; source = 'Prompt' }
    }
}

Describe 'Invoke-AIGovAzureList' {
    It 'follows nextLink and carries the skip token in the api-version' {
        Mock Invoke-MtAzureRequest {
            if ($ApiVersion -eq '2024-10-01') { return @{ value = @('a', 'b'); nextLink = 'https://management.azure.com/sub/x/deployments?api-version=2024-10-01&$skiptoken=abc' } }
            if ($ApiVersion -eq '2024-10-01&$skiptoken=abc' -and $RelativeUri -eq '/sub/x/deployments') { return @{ value = @('c') } }
            throw "Unexpected call: $RelativeUri $ApiVersion"
        }
        $Items = Invoke-AIGovAzureList -RelativeUri '/sub/x/deployments' -ApiVersion '2024-10-01'
        $Items.Count | Should -Be 3
    }

    It 'returns $null on 403 and an empty array for an empty list' {
        Mock Invoke-MtAzureRequest { $null }
        $null -eq (Invoke-AIGovAzureList -RelativeUri '/x' -ApiVersion '1') | Should -Be $true
        Mock Invoke-MtAzureRequest { @{ value = @() } }
        $Items = Invoke-AIGovAzureList -RelativeUri '/x' -ApiVersion '1'
        $null -eq $Items | Should -Be $false
        $Items.Count | Should -Be 0
    }
}

Describe 'Get-AIGovAzureAiDeployment' {
    It 'returns one row per deployment with the model and content filter' {
        Set-AzureRoute @{ '/deployments$' = @{ value = @((New-Deployment 'd1' 'gpt-4.1' '2025-04-14' 'Custom1')) } }
        $Row = @(New-Account 'a1' | Get-AIGovAzureAiDeployment)
        $Row.Count | Should -Be 1
        $Row[0].Model | Should -Be 'gpt-4.1'
        $Row[0].Version | Should -Be '2025-04-14'
        $Row[0].RaiPolicy | Should -Be 'Custom1'
        $Row[0].ReadError | Should -BeNullOrEmpty
    }

    It 'returns a ReadError row when the account answers 403' {
        Set-AzureRoute @{ '/deployments$' = $null }
        $Row = @(New-Account 'a1' | Get-AIGovAzureAiDeployment)
        $Row.Count | Should -Be 1
        $Row[0].ReadError | Should -Match 'no access'
    }
}

Describe 'Test-MPAIGOV1046' {
    BeforeEach {
        Mock Add-MtTestResultDetail {}
        Mock Invoke-MtAzureResourceGraphRequest { @((New-Account 'a1')) }
    }

    It 'passes when there are no AI accounts' {
        Mock Invoke-MtAzureResourceGraphRequest { @() }
        Test-MPAIGOV1046 | Should -Be $true
    }

    It 'passes when the content filter blocks Prompt Shields for user prompts' {
        Set-AzureRoute @{
            '/deployments$' = @{ value = @((New-Deployment 'd1' 'gpt-4.1' '1' 'Strict')) }
            '/raiPolicies$' = @{ value = @(@{ name = 'Strict'; properties = @{ mode = 'Blocking'; contentFilters = @((New-Filter 'Jailbreak')) } }) }
        }
        Test-MPAIGOV1046 | Should -Be $true
    }

    It 'passes Microsoft.DefaultV2 when the account does not list it' {
        Set-AzureRoute @{
            '/deployments$' = @{ value = @((New-Deployment 'd1' 'gpt-4.1' '1' 'Microsoft.DefaultV2')) }
            '/raiPolicies$' = @{ value = @() }
        }
        Test-MPAIGOV1046 | Should -Be $true
    }

    It 'fails Medium for no filter and an annotate-only jailbreak filter' {
        Set-AzureRoute @{
            '/deployments$' = @{ value = @((New-Deployment 'd1' 'gpt-4.1' '1' ''), (New-Deployment 'd2' 'gpt-4o' '1' 'Loose')) }
            '/raiPolicies$' = @{ value = @(@{ name = 'Loose'; properties = @{ mode = 'Asynchronous_filter'; contentFilters = @((New-Filter 'Jailbreak' $true $false)) } }) }
        }
        Test-MPAIGOV1046 | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Severity -eq 'Medium' -and $Result -match 'Found 2 of 2' -and $Result -match 'no content filter' -and $Result -match 'annotate-only'
        }
    }

    It 'accepts a guardrail control with action BLOCKING' {
        Set-AzureRoute @{
            '/deployments$' = @{ value = @((New-Deployment 'd1' 'gpt-4.1' '1' 'Guard')) }
            '/raiPolicies$' = @{ value = @(@{ name = 'Guard'; properties = @{ contentFilters = @(@{ name = 'Jailbreak'; enabled = $true; action = 'BLOCKING'; source = 'Prompt' }) } }) }
        }
        Test-MPAIGOV1046 | Should -Be $true
    }

    It 'leaves out embedding models' {
        Set-AzureRoute @{
            '/deployments$' = @{ value = @((New-Deployment 'e1' 'text-embedding-3-large' '1' '')) }
        }
        Test-MPAIGOV1046 | Should -Be $true
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Result -match '1 embedding' }
    }

    It 'requires the indirect attack filter only when asked' {
        Set-AzureRoute @{
            '/deployments$' = @{ value = @((New-Deployment 'd1' 'gpt-4.1' '1' 'Strict')) }
            '/raiPolicies$' = @{ value = @(@{ name = 'Strict'; properties = @{ contentFilters = @((New-Filter 'Jailbreak'), (New-Filter 'Indirect Attack' $false $false)) } }) }
        }
        Test-MPAIGOV1046 | Should -Be $true
        Test-MPAIGOV1046 -RequireIndirectAttackFilter $true | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -ParameterFilter { $Result -match 'indirect attacks off' }
    }

    It 'skips when no content filter can be read' {
        Set-AzureRoute @{
            '/deployments$' = @{ value = @((New-Deployment 'd1' 'gpt-4.1' '1' 'Strict')) }
            '/raiPolicies$' = $null
        }
        Test-MPAIGOV1046 | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'Custom' }
    }

    It 'skips when Resource Graph fails' {
        Mock Invoke-MtAzureResourceGraphRequest { throw 'not connected' }
        Test-MPAIGOV1046 | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'Custom' }
    }
}

Describe 'Test-MPAIGOV1047' {
    BeforeEach {
        Mock Add-MtTestResultDetail {}
        Mock Invoke-MtAzureResourceGraphRequest { @((New-Account 'a1')) }
    }

    It 'passes when allLogs goes to a workspace' {
        Set-AzureRoute @{ 'diagnosticSettings$' = @{ value = @(@{ properties = @{ workspaceId = 'w'; logs = @(@{ categoryGroup = 'allLogs'; enabled = $true }) } }) } }
        Test-MPAIGOV1047 | Should -Be $true
    }

    It 'passes when Audit and RequestResponse are on by category' {
        Set-AzureRoute @{ 'diagnosticSettings$' = @{ value = @(@{ properties = @{ storageAccountId = 's'; logs = @(@{ category = 'Audit'; enabled = $true }, @{ category = 'RequestResponse'; enabled = $true }) } }) } }
        Test-MPAIGOV1047 | Should -Be $true
    }

    It 'fails when there is no diagnostic setting' {
        Set-AzureRoute @{ 'diagnosticSettings$' = @{ value = @() } }
        Test-MPAIGOV1047 | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Severity -eq 'Medium' -and $Result -match 'no diagnostic setting' }
    }

    It 'fails when only the audit group is exported, and ignores settings without a destination' {
        Set-AzureRoute @{ 'diagnosticSettings$' = @{ value = @(
                    @{ properties = @{ workspaceId = 'w'; logs = @(@{ categoryGroup = 'audit'; enabled = $true }) } }
                    @{ properties = @{ logs = @(@{ category = 'RequestResponse'; enabled = $true }) } }
                ) } }
        Test-MPAIGOV1047 | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Result -match 'not exported: RequestResponse' }
    }

    It 'skips when no diagnostic settings can be read' {
        Set-AzureRoute @{ 'diagnosticSettings$' = $null }
        Test-MPAIGOV1047 | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'Custom' }
    }
}

Describe 'Test-MPAIGOV1048' {
    BeforeEach {
        Mock Add-MtTestResultDetail {}
        Mock Invoke-MtAzureResourceGraphRequest { @((New-Account 'a1')) }
        Set-AzureRoute @{ '/deployments$' = @{ value = @((New-Deployment 'd1' 'gpt-4.1' '2025-04-14'), (New-Deployment 'd2' 'gpt-4o' '2024-05-13'), (New-Deployment 'd3' 'Llama-3.3-70B' '1')) } }
    }

    It 'skips until AIGOV.ApprovedModels is set' {
        Test-MPAIGOV1048 | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'Custom' -and $SkippedCustomReason -match 'AIGOV.ApprovedModels' }
        Should -Invoke Invoke-MtAzureResourceGraphRequest -Times 0
    }

    It 'passes when every model matches by name, version or wildcard' {
        Test-MPAIGOV1048 -ApprovedModels 'GPT-4.1', 'gpt-4o:2024-05-13', 'llama-*' | Should -Be $true
    }

    It 'fails for a model or version that is not approved' {
        Test-MPAIGOV1048 -ApprovedModels 'gpt-4.1', 'gpt-4o:2024-11-20' | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Severity -eq 'Medium' -and $Result -match 'Found 2 of 3' -and $Result -match 'gpt-4o' -and $Result -match 'Llama-3.3-70B' -and $Result -notmatch '\| d1 \|'
        }
    }

    It 'skips when no deployments can be read' {
        Set-AzureRoute @{ '/deployments$' = $null }
        Test-MPAIGOV1048 -ApprovedModels 'gpt-4.1' | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'Custom' }
    }
}
