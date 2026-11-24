function Test-MPAIGOV1056 {
    <#
    .SYNOPSIS
    Finds Microsoft Foundry guardrails (RAI policies) whose hosted agent egress rules don't block by default.
    .DESCRIPTION
    Reads the accounts from Azure Resource Graph, then each account's RAI policies (GET
    {account}/raiPolicies, api-version 2026-09-01) from Azure Resource Manager. A hosted agent's network
    egress rules are stored on the RAI policy it uses, in properties.egressPolicy. A policy with egress
    rules fails when:

    - Its mode is Audit: requests that should be denied are only logged.
    - Its default action is Allow: any host no rule names is reachable.
    - It has an Allow rule that matches every host (no host, or *): that rule lets everything through
      before the default action is reached.

    Azure defaults a missing mode to Enforced and a missing default action to Deny, so a missing value
    counts as that default. Policies without egress rules are counted for information: most only filter
    model content. Hosted agents themselves can't be read from Azure Resource Manager, so this test can't
    tell which agents use no egress rules at all. No accounts, or no egress rules, is a pass.
    .EXAMPLE
    Test-MPAIGOV1056
    .LINK
    https://learn.microsoft.com/azure/foundry/agents/how-to/add-hosted-agent-guardrails#network-egress-controls
    .LINK
    https://learn.microsoft.com/azure/foundry/agents/how-to/govern-hosted-agent-egress-azure-policy
    .LINK
    https://learn.microsoft.com/security/benchmark/azure/mcsb-v2-artificial-intelligence-security
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1056',
        Title        = 'Foundry hosted agent egress rules should be enforced and deny by default',
        Product      = 'azure',
        Feature      = 'network-security',
        Area         = 'ai',
        ResourceType = 'AzureResource',
        Severity     = 'Medium',
        Control      = 'nist-800-53-r5:SC-7',
        Service      = 'Azure',
        Lifecycle    = 'Preview'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # egressPolicy is in the stable RAI policy API from 2026-09-01. Older versions don't return it.
    $ApiVersion = '2026-09-01'

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

    # One row per account: its RAI policies, or the reason they couldn't be read.
    $AccountRows = @(
        foreach ($Account in $Accounts) {
            $Policies = $null
            $ReadError = try {
                $Policies = Invoke-AIGovAzureList -RelativeUri "$($Account.id)/raiPolicies" -ApiVersion $ApiVersion
                if ($null -eq $Policies) { 'no access' }
            } catch {
                Write-Verbose "Couldn't read the RAI policies of $($Account.id): $($_.Exception.Message)"
                $_.Exception.Message
            }
            $Account | Select-Object @{ n = 'Account'; e = { $_.name } }, @{ n = 'Subscription'; e = { $_.subscriptionId } },
                @{ n = 'Policies'; e = { @($Policies) } }, @{ n = 'ReadError'; e = { $ReadError } }
        }
    )

    $Read = @($AccountRows | Where-Object { -not $_.ReadError })
    $Unread = @($AccountRows | Where-Object ReadError)
    if ($Read.Count -eq 0) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Couldn't read the RAI policies of any of the $($Unread.Count) AI account(s). Maester needs Reader on those subscriptions, and the region must support api-version $ApiVersion."
        return $null
    }

    $AllPolicies = @(foreach ($Row in $Read) { $Row.Policies | Where-Object { $null -ne $_ } | Select-Object @{ n = 'Account'; e = { $Row.Account } }, @{ n = 'Subscription'; e = { $Row.Subscription } }, name, properties })
    $WithEgress = @($AllPolicies | Where-Object { $null -ne $_.properties.egressPolicy })

    $Checked = @(
        foreach ($Policy in $WithEgress) {
            $Egress = $Policy.properties.egressPolicy
            $Mode = if ([string]$Egress.mode) { [string]$Egress.mode } else { 'Enforced' }
            $Default = if ([string]$Egress.defaultAction) { [string]$Egress.defaultAction } else { 'Deny' }
            $Rules = @($Egress.rules | Where-Object { $null -ne $_ })
            # An Allow rule with no host, or *, matches every request it reaches.
            $OpenRules = @($Rules | Where-Object {
                    [string]$_.action.actionType -eq 'Allow' -and ([string]$_.match.host).Trim() -in @('', '*')
                } | ForEach-Object { [string]$_.name })

            $Reasons = @(
                if ($Mode -ne 'Enforced') { "mode is $Mode, so denied requests are only logged" }
                if ($Default -ne 'Deny') { "default action is $Default" }
                if ($OpenRules.Count -gt 0) { "Allow rule matches every host: $($OpenRules -join ', ')" }
            )
            $Policy | Select-Object Account, Subscription, @{ n = 'RAI policy'; e = { $_.name } },
                @{ n = 'Mode'; e = { $Mode } }, @{ n = 'Default action'; e = { $Default } },
                @{ n = 'Rules'; e = { $Rules.Count } },
                @{ n = 'Status'; e = { if ($Reasons.Count -gt 0) { 'Fail' } else { 'Pass' } } },
                @{ n = 'Reason'; e = { $Reasons -join '; ' } }
        }
    )

    $Findings = @($Checked | Where-Object Status -EQ 'Fail')
    $Notes = @(
        if ($AllPolicies.Count -gt $WithEgress.Count) { "$($AllPolicies.Count - $WithEgress.Count) RAI policy or policies have no egress rules. That's normal for a policy that only filters model content." }
        if ($Unread.Count -gt 0) { "Couldn't read the RAI policies of $($Unread.Count) account(s): $(@($Unread.Account) -join ', ')." }
        'Hosted agents themselves aren''t in Azure Resource Manager, so a hosted agent that uses no RAI policy with egress rules isn''t found here. Review those in the Foundry portal, or assign the Azure Policy built-in *Microsoft Foundry hosted agents should enforce resolved RAI egress restrictions*.'
    )

    if ($Findings.Count -eq 0) {
        $Pass = if ($Checked.Count -eq 0) {
            "No RAI policy in $($Read.Count) AI account(s) has hosted agent egress rules."
        } else {
            "Well done. All $($Checked.Count) RAI policy or policies with egress rules are enforced and deny by default."
        }
        Add-MtTestResultDetail -Result (@($Pass) + $Notes -join "`n`n")
        return $true
    }

    $Result = @(
        "Found $($Findings.Count) of $($Checked.Count) RAI policy or policies whose hosted agent egress rules don't block by default."
        $Findings | Sort-Object Subscription, Account, 'RAI policy' | ConvertTo-AIGovMarkdownTable -Property 'Account', 'RAI policy', 'Mode', 'Default action', 'Rules', 'Reason'
        $Notes
    ) -join "`n`n"
    Add-MtTestResultDetail -Result $Result -Severity 'Medium'
    return $false
}
