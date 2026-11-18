function Test-MPAIGOV1045 {
    <#
    .SYNOPSIS
    Finds Azure OpenAI and Azure AI Services accounts open to key auth or the public internet, or not covered by Defender.
    .DESCRIPTION
    Reads Azure Resource Graph for Microsoft.CognitiveServices/accounts of kind OpenAI or AIServices
    (the resources behind Microsoft Foundry and Azure OpenAI), then each subscription's Defender for
    Cloud AI plan (GET /subscriptions/{id}/providers/Microsoft.Security/pricings/AI). An account fails
    when:

    - disableLocalAuth isn't true: anyone with an API key can call the model, with no Entra identity,
      Conditional Access or per-caller audit.
    - publicNetworkAccess is Enabled and networkAcls.defaultAction isn't Deny: the endpoint accepts
      calls from any network.
    - Its subscription's Defender for AI Services plan isn't on (pricingTier not Standard): no
      prompt-injection, jailbreak or data-leak alerts for the account.

    Only subscriptions that hold such an account are checked for the plan. No accounts is a pass.
    This is the one Azure check in the pack; Azure Policy may already enforce these settings.
    .EXAMPLE
    Test-MPAIGOV1045
    .LINK
    https://learn.microsoft.com/azure/ai-services/disable-local-auth
    .LINK
    https://learn.microsoft.com/azure/defender-for-cloud/ai-threat-protection
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1045',
        Title        = 'Azure OpenAI and AI Services accounts should require Entra auth, restrict network access and be covered by Defender for AI',
        Product      = 'azure',
        Feature      = 'network-security',
        Area         = 'ai',
        ResourceType = 'AzureResource',
        Severity     = 'Medium',
        Control      = 'nist-800-53-r5:IA-2',
        Service      = 'Azure',
        Lifecycle    = 'Preview'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $Query = @'
Resources
| where type =~ 'microsoft.cognitiveservices/accounts'
| where kind in~ ('OpenAI', 'AIServices')
| project id, name, subscriptionId, resourceGroup, kind,
    disableLocalAuth = tobool(properties.disableLocalAuth),
    publicNetworkAccess = tostring(properties.publicNetworkAccess),
    defaultAction = tostring(properties.networkAcls.defaultAction)
'@

    try {
        Write-Verbose 'Querying Azure Resource Graph for Azure OpenAI and AI Services accounts.'
        $Accounts = @(Invoke-MtAzureResourceGraphRequest -Query $Query | Where-Object { $null -ne $_ })
    } catch {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Couldn't query Azure Resource Graph for AI accounts." -SkippedError $_
        return $null
    }

    if ($Accounts.Count -eq 0) {
        Add-MtTestResultDetail -Result 'No Azure OpenAI or Azure AI Services accounts were found in the subscriptions Maester can read.'
        return $true
    }

    $PlanBySubscription = @{}
    foreach ($SubscriptionId in @($Accounts | Select-Object -ExpandProperty subscriptionId -Unique)) {
        $PlanBySubscription[$SubscriptionId] = try {
            [string](Invoke-MtAzureRequest -RelativeUri "/subscriptions/$SubscriptionId/providers/Microsoft.Security/pricings/AI" -ApiVersion '2024-01-01').properties.pricingTier
        } catch {
            Write-Verbose "Couldn't read the Defender AI plan for $SubscriptionId`: $($_.Exception.Message)"
            'unknown'
        }
    }

    $Findings = @(
        foreach ($Account in $Accounts) {
            $Plan = $PlanBySubscription[[string]$Account.subscriptionId]
            $Reasons = @(
                if ($Account.disableLocalAuth -ne $true) { 'key auth allowed' }
                if ([string]$Account.publicNetworkAccess -ne 'Disabled' -and [string]$Account.defaultAction -ne 'Deny') { 'public network access' }
                if ($Plan -ne 'Standard') { "Defender for AI Services off ($Plan)" }
            )
            if ($Reasons.Count -gt 0) {
                $Account | Select-Object @{ n = 'Account'; e = { [string]$_.name } }, @{ n = 'Kind'; e = { [string]$_.kind } },
                    @{ n = 'Subscription'; e = { [string]$_.subscriptionId } }, @{ n = 'Resource group'; e = { [string]$_.resourceGroup } },
                    @{ n = 'Reason'; e = { $Reasons -join '; ' } }
            }
        }
    )

    if ($Findings.Count -eq 0) {
        Add-MtTestResultDetail -Result (
            "Well done. All $($Accounts.Count) Azure OpenAI or AI Services account(s) require Entra auth, restrict network access, and are covered by Defender for AI Services."
        )
        return $true
    }

    $Result = @(
        "Found $($Findings.Count) of $($Accounts.Count) Azure OpenAI or AI Services account(s) with at least one gap."
        $Findings | Sort-Object Subscription, Account | ConvertTo-AIGovMarkdownTable -Property 'Account', 'Kind', 'Subscription', 'Resource group', 'Reason'
    ) -join "`n`n"
    Add-MtTestResultDetail -Result $Result -Severity 'Medium'
    return $false
}
