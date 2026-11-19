function Test-MPAIGOV1047 {
    <#
    .SYNOPSIS
    Finds Azure OpenAI and AI Services accounts that don't export their audit and request logs.
    .DESCRIPTION
    Reads the accounts from Azure Resource Graph, then each account's diagnostic settings
    (GET {account}/providers/Microsoft.Insights/diagnosticSettings) from Azure Resource Manager.
    Resource logs aren't kept anywhere until a diagnostic setting sends them to Log Analytics, a storage
    account, an event hub or a partner solution.

    An account fails when no diagnostic setting with a destination turns on each required log
    category (AIGOV.RequiredAiLogCategories, default Audit and RequestResponse). The allLogs category
    group counts for every category, and the audit group counts for Audit. No accounts is a pass.
    .PARAMETER RequiredCategories
    Resource log categories that must be exported. Microsoft.CognitiveServices/accounts supports Audit,
    RequestResponse, Trace, AzureOpenAIRequestUsage and ManagedNetworkEvent.
    .EXAMPLE
    Test-MPAIGOV1047
    .LINK
    https://learn.microsoft.com/azure/azure-monitor/reference/supported-logs/microsoft-cognitiveservices-accounts-logs
    .LINK
    https://learn.microsoft.com/azure/ai-foundry/openai/how-to/monitor-openai
    .LINK
    https://learn.microsoft.com/security/benchmark/azure/mcsb-v2-artificial-intelligence-security
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1047',
        Title        = 'Azure OpenAI and AI Services accounts should export their audit and request logs',
        Product      = 'azure',
        Feature      = 'logging',
        Area         = 'ai',
        ResourceType = 'AzureResource',
        Severity     = 'Medium',
        Control      = 'nist-800-53-r5:AU-12',
        Service      = 'Azure',
        Lifecycle    = 'Preview'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [MaesterParameter(Setting = 'AIGOV.RequiredAiLogCategories')]
        [string[]]$RequiredCategories = @('Audit', 'RequestResponse')
    )

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

    $Checked = @(
        foreach ($Account in $Accounts) {
            $Settings = try {
                Invoke-AIGovAzureList -RelativeUri "$([string]$Account.id)/providers/Microsoft.Insights/diagnosticSettings" -ApiVersion '2021-05-01-preview'
            } catch {
                Write-Verbose "Couldn't read the diagnostic settings of $($Account.id): $($_.Exception.Message)"
                $null
            }

            # Categories exported by settings that send logs somewhere.
            $Exported = @(
                foreach ($Setting in @($Settings)) {
                    $P = $Setting.properties
                    if (-not ($P.workspaceId -or $P.storageAccountId -or $P.eventHubAuthorizationRuleId -or $P.marketplacePartnerId)) { continue }
                    foreach ($Log in @($P.logs | Where-Object { $_.enabled -eq $true })) {
                        if ($Log.category) { [string]$Log.category }
                        if ($Log.categoryGroup -eq 'allLogs') { $RequiredCategories }
                        if ($Log.categoryGroup -eq 'audit') { 'Audit' }
                    }
                }
            )
            $Missing = @($RequiredCategories | Where-Object { $_ -notin $Exported })

            $Account | Select-Object @{ n = 'Account'; e = { [string]$_.name } }, @{ n = 'Kind'; e = { [string]$_.kind } },
                @{ n = 'Subscription'; e = { [string]$_.subscriptionId } }, @{ n = 'Resource group'; e = { [string]$_.resourceGroup } },
                @{ n = 'Status'; e = { if ($null -eq $Settings) { 'Unread' } elseif ($Missing.Count -gt 0) { 'Fail' } else { 'Pass' } } },
                @{ n = 'Reason'; e = {
                        if ($null -ne $Settings -and $Settings.Count -eq 0) { 'no diagnostic setting' }
                        elseif ($Missing.Count -gt 0) { "not exported: $($Missing -join ', ')" }
                    }
                }
        }
    )

    $Findings = @($Checked | Where-Object Status -EQ 'Fail')
    $Unread = @($Checked | Where-Object Status -EQ 'Unread')

    if ($Unread.Count -eq $Checked.Count) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Couldn't read the diagnostic settings of any of the $($Checked.Count) AI account(s). Maester needs Reader on those subscriptions."
        return $null
    }

    $Note = if ($Unread.Count -gt 0) { "Couldn't read the diagnostic settings of $($Unread.Count) account(s): $(@($Unread.Account) -join ', ')." }

    if ($Findings.Count -eq 0) {
        Add-MtTestResultDetail -Result ((@(
                "Well done. All $($Checked.Count - $Unread.Count) AI account(s) checked export $($RequiredCategories -join ' and ') logs."
                $Note
            ) | Where-Object { $_ }) -join "`n`n")
        return $true
    }

    $Result = (@(
        "Found $($Findings.Count) of $($Checked.Count) AI account(s) that don't export $($RequiredCategories -join ' and ') logs."
        $Findings | Sort-Object Subscription, Account | ConvertTo-AIGovMarkdownTable -Property 'Account', 'Kind', 'Subscription', 'Resource group', 'Reason'
        $Note
    ) | Where-Object { $_ }) -join "`n`n"
    Add-MtTestResultDetail -Result $Result -Severity 'Medium'
    return $false
}
