function Test-MPAIGOV1048 {
    <#
    .SYNOPSIS
    Finds Azure OpenAI and AI Services model deployments that use a model not on your approved list.
    .DESCRIPTION
    Reads the accounts from Azure Resource Graph, then each account's model deployments
    (GET {account}/deployments) from Azure Resource Manager, and compares each deployment's model to
    AIGOV.ApprovedModels.

    Each approved entry is a model name ("gpt-4.1") or a name and version ("gpt-4o:2024-11-20").
    Wildcards work ("gpt-5*"). Matching ignores case. A deployment fails when no entry matches it.

    Skipped until you set AIGOV.ApprovedModels, because only you know which models you approved.
    No deployments is a pass.
    .PARAMETER ApprovedModels
    Approved models as name or name:version, with optional wildcards.
    .EXAMPLE
    Test-MPAIGOV1048 -ApprovedModels 'gpt-4.1', 'gpt-4o:2024-11-20', 'text-embedding-3-*'
    .LINK
    https://learn.microsoft.com/security/benchmark/azure/mcsb-v2-artificial-intelligence-security
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1048',
        Title        = 'Azure AI model deployments should only use approved models',
        Product      = 'azure',
        Feature      = 'model-governance',
        Area         = 'ai',
        ResourceType = 'AzureResource',
        Severity     = 'Medium',
        Control      = 'nist-800-53-r5:CM-7',
        Service      = 'Azure',
        Lifecycle    = 'Preview'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [MaesterParameter(Setting = 'AIGOV.ApprovedModels')]
        [string[]]$ApprovedModels = @()
    )

    $ApprovedModels = @($ApprovedModels | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($ApprovedModels.Count -eq 0) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason (
            "Set AIGOV.ApprovedModels to the models you allow, as name or name:version (for example 'gpt-4.1' or 'gpt-4o:2024-11-20')."
        )
        return $null
    }

    try {
        $Accounts = @(Get-AIGovAzureAiAccount)
    } catch {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Couldn't query Azure Resource Graph for AI accounts." -SkippedError $_
        return $null
    }
    if ($Accounts.Count -eq 0) {
        Add-MtTestResultDetail -Result 'No Azure OpenAI or Azure AI Services accounts were found in the subscriptions Maester can read.'
        return $true
    }

    $Rows = @($Accounts | Get-AIGovAzureAiDeployment)
    $UnreadAccounts = @($Rows | Where-Object ReadError)
    $Deployments = @($Rows | Where-Object { -not $_.ReadError })

    if ($Deployments.Count -eq 0 -and $UnreadAccounts.Count -gt 0) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Couldn't read the model deployments of $($UnreadAccounts.Count) AI account(s). Maester needs Reader on those subscriptions."
        return $null
    }

    $Findings = @(
        $Deployments | Where-Object {
            $Name = [string]$_.Model
            $Full = "$Name`:$([string]$_.Version)"
            -not @($ApprovedModels | Where-Object { if ($_ -match ':') { $Full -like $_ } else { $Name -like $_ } })
        } | Select-Object Account, Subscription, 'Resource group', Deployment,
            @{ n = 'Model'; e = { if ($_.Model) { $_.Model } else { '(unknown)' } } },
            @{ n = 'Version'; e = { [string]$_.Version } },
            @{ n = 'Publisher'; e = { @($_.Publisher, $_.Format) | Where-Object { $_ } | Select-Object -First 1 } }
    )

    $Note = if ($UnreadAccounts.Count -gt 0) { "Couldn't read the deployments of $($UnreadAccounts.Count) account(s): $(@($UnreadAccounts.Account) -join ', ')." }

    if ($Findings.Count -eq 0) {
        $Pass = if ($Deployments.Count -eq 0) { "No model deployments were found in $($Accounts.Count) AI account(s)." }
            else { "Well done. All $($Deployments.Count) model deployment(s) use an approved model." }
        Add-MtTestResultDetail -Result (@($Pass, $Note | Where-Object { $_ }) -join "`n`n")
        return $true
    }

    $Result = (@(
        "Found $($Findings.Count) of $($Deployments.Count) model deployment(s) using a model that isn't in AIGOV.ApprovedModels."
        $Findings | Sort-Object Subscription, Account, Deployment | ConvertTo-AIGovMarkdownTable -Property 'Account', 'Deployment', 'Model', 'Version', 'Publisher', 'Resource group'
        $Note
    ) | Where-Object { $_ }) -join "`n`n"
    Add-MtTestResultDetail -Result $Result -Severity 'Medium'
    return $false
}
