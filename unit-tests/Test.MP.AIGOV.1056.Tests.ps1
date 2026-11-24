BeforeAll {
    . "$PSScriptRoot/../pack/helpers/ConvertTo-AIGovMarkdownCell.ps1"
    . "$PSScriptRoot/../pack/helpers/ConvertTo-AIGovMarkdownTable.ps1"
    . "$PSScriptRoot/../pack/helpers/Get-AIGovAzureAiAccount.ps1"
    . "$PSScriptRoot/../pack/helpers/Invoke-AIGovAzureList.ps1"
    . "$PSScriptRoot/../pack/tests/Test.MP.AIGOV.1056.ps1"

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
        @{ id = "/subscriptions/$Sub/resourceGroups/rg/providers/Microsoft.CognitiveServices/accounts/$Name"; name = $Name; subscriptionId = $Sub; resourceGroup = 'rg'; kind = 'AIServices' }
    }
    function New-Rule([string]$Name, [string]$Action = 'Allow', [string]$HostName = 'api.contoso.com') {
        $Match = if ($HostName -eq '<none>') { $null } else { @{ host = $HostName } }
        @{ name = $Name; ruleType = 'Fqdn'; match = $Match; action = @{ actionType = $Action } }
    }
    function New-Policy([string]$Name, $Egress) {
        $Properties = @{ mode = 'Blocking'; contentFilters = @(@{ name = 'Jailbreak'; enabled = $true; blocking = $true; source = 'Prompt' }) }
        if ($null -ne $Egress) { $Properties.egressPolicy = $Egress }
        @{ name = $Name; properties = $Properties }
    }
}

Describe 'Test-MPAIGOV1056' {
    BeforeEach {
        Mock Add-MtTestResultDetail {}
        Mock Invoke-MtAzureResourceGraphRequest { @((New-Account 'a1')) }
    }

    It 'passes when there are no AI accounts' {
        Mock Invoke-MtAzureResourceGraphRequest { @() }
        Test-MPAIGOV1056 | Should -Be $true
    }

    It 'reads RAI policies with api-version 2026-09-01' {
        Mock Invoke-MtAzureRequest { @{ value = @() } }
        Test-MPAIGOV1056 | Should -Be $true
        Should -Invoke Invoke-MtAzureRequest -Times 1 -ParameterFilter { $RelativeUri -match '/raiPolicies$' -and $ApiVersion -eq '2026-09-01' }
    }

    It 'passes when no policy has egress rules, and says so' {
        Set-AzureRoute @{ '/raiPolicies$' = @{ value = @((New-Policy 'Filter1' $null)) } }
        Test-MPAIGOV1056 | Should -Be $true
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Result -match 'No RAI policy in 1 AI account' -and $Result -match '1 RAI policy or policies have no egress rules' -and $Result -match 'Hosted agents themselves'
        }
    }

    It 'passes an enforced deny-by-default policy with named hosts' {
        Set-AzureRoute @{ '/raiPolicies$' = @{ value = @((New-Policy 'Egress1' @{ mode = 'Enforced'; defaultAction = 'Deny'; rules = @((New-Rule 'pypi' 'Allow' 'pypi.org'), (New-Rule 'gh' 'Allow' '*.github.com')) })) } }
        Test-MPAIGOV1056 | Should -Be $true
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Result -match 'Well done. All 1 RAI policy' }
    }

    It 'treats a missing mode and default action as Enforced and Deny' {
        Set-AzureRoute @{ '/raiPolicies$' = @{ value = @((New-Policy 'Egress1' @{ rules = @((New-Rule 'pypi')) })) } }
        Test-MPAIGOV1056 | Should -Be $true
    }

    It 'fails Medium for Audit mode and a default of Allow' {
        Set-AzureRoute @{ '/raiPolicies$' = @{ value = @(
                    (New-Policy 'AuditOnly' @{ mode = 'Audit'; defaultAction = 'Deny'; rules = @((New-Rule 'pypi')) })
                    (New-Policy 'OpenDefault' @{ mode = 'Enforced'; defaultAction = 'Allow'; rules = @((New-Rule 'bad' 'Deny' 'evil.example')) })
                ) } }
        Test-MPAIGOV1056 | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Severity -eq 'Medium' -and $Result -match 'Found 2 of 2' -and $Result -match 'mode is Audit' -and $Result -match 'default action is Allow'
        }
    }

    It 'fails an Allow rule with no host or a * host' {
        Set-AzureRoute @{ '/raiPolicies$' = @{ value = @(
                    (New-Policy 'Wide1' @{ mode = 'Enforced'; defaultAction = 'Deny'; rules = @((New-Rule 'anything' 'Allow' '<none>')) })
                    (New-Policy 'Wide2' @{ mode = 'Enforced'; defaultAction = 'Deny'; rules = @((New-Rule 'star' 'Allow' '*'), (New-Rule 'blockstar' 'Deny' '*')) })
                ) } }
        Test-MPAIGOV1056 | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Result -match 'Found 2 of 2' -and $Result -match 'every host: anything' -and $Result -match 'every host: star' -and $Result -notmatch 'blockstar'
        }
    }

    It 'notes accounts it could not read and still checks the rest' {
        Mock Invoke-MtAzureResourceGraphRequest { @((New-Account 'a1'), (New-Account 'a2')) }
        Set-AzureRoute @{
            'accounts/a1/raiPolicies$' = @{ value = @((New-Policy 'AuditOnly' @{ mode = 'Audit'; defaultAction = 'Deny' })) }
            'accounts/a2/raiPolicies$' = $null
        }
        Test-MPAIGOV1056 | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Result -match 'Found 1 of 1' -and $Result -match "Couldn't read the RAI policies of 1 account\(s\): a2" }
    }

    It 'skips when no account can be read' {
        Set-AzureRoute @{ '/raiPolicies$' = 'throw' }
        Test-MPAIGOV1056 | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'Custom' -and $SkippedCustomReason -match '2026-09-01' }
    }

    It 'skips when Resource Graph fails' {
        Mock Invoke-MtAzureResourceGraphRequest { throw 'not connected' }
        Test-MPAIGOV1056 | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'Custom' }
    }
}
